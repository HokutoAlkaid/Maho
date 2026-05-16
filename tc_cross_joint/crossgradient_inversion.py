import sys
import numpy as np
from scipy.sparse import bmat, diags, eye
from scipy.sparse.linalg import lsmr

# ===== Joint inversion configuration =====
# Keep the commonly tuned parameters near the top of the file so each
# inversion only needs one quick edit here.
KM_PER_DEG = 111.32
ALPHA_S = 1.0
ALPHA_G = 1.0
BETA_T = 0.1


def ordered_unique(values):
    unique_values, first_indices = np.unique(values, return_index=True)
    return unique_values[np.argsort(first_indices)]


def axis_to_km(axis_values_deg, scale):
    axis_values_deg = np.asarray(axis_values_deg, dtype=float)
    return (axis_values_deg - axis_values_deg[0]) * scale


def build_grid_coordinates(lat_values_deg, lon_values_deg, depth_values_km):
    mean_lat = float(np.mean(lat_values_deg))
    lat_km = axis_to_km(lat_values_deg, KM_PER_DEG)
    lon_km = axis_to_km(lon_values_deg, KM_PER_DEG * np.cos(np.deg2rad(mean_lat)))
    depth_km = np.asarray(depth_values_km, dtype=float)
    return lat_km, lon_km, depth_km, mean_lat


def central_span(axis_values, idx):
    return float(axis_values[idx + 1] - axis_values[idx - 1])


def compute_model_gradients(model, lat_km, lon_km, depth_km):
    dmdlat, dmdlon, dmdz = np.gradient(
        model,
        lat_km,
        lon_km,
        depth_km,
        edge_order=2,
    )
    return dmdlat, dmdlon, dmdz


def central_difference(m1, m2, lat_km, lon_km, depth_km):
    dm1_dlat, dm1_dlon, dm1_dz = compute_model_gradients(m1, lat_km, lon_km, depth_km)
    dm2_dlat, dm2_dlon, dm2_dz = compute_model_gradients(m2, lat_km, lon_km, depth_km)

    tx = dm1_dlon * dm2_dz - dm1_dz * dm2_dlon
    ty = dm1_dz * dm2_dlat - dm1_dlat * dm2_dz
    tz = dm1_dlat * dm2_dlon - dm1_dlon * dm2_dlat
    return tx, ty, tz


def calculate_gradient_derivatives(m1, m2, lat_km, lon_km, depth_km):
    nx, ny, nz = m1.shape
    dtx_dms_x = np.zeros_like(m1)
    dtx_dms_y = np.zeros_like(m1)
    dtx_dms_z = np.zeros_like(m1)
    dtx_dmg_x = np.zeros_like(m1)
    dtx_dmg_y = np.zeros_like(m1)
    dtx_dmg_z = np.zeros_like(m1)

    for i in range(1, nx - 1):
        inv_dlat = 1.0 / central_span(lat_km, i)
        for j in range(1, ny - 1):
            inv_dlon = 1.0 / central_span(lon_km, j)
            for k in range(1, nz - 1):
                inv_dz = 1.0 / central_span(depth_km, k)

                dtx_dms_x[i, j, k] = (m2[i, j, k + 1] - m2[i, j, k - 1]) * inv_dz * inv_dlon
                dtx_dms_y[i, j, k] = (m2[i + 1, j, k] - m2[i - 1, j, k]) * inv_dlat * inv_dz
                dtx_dms_z[i, j, k] = (m2[i + 1, j, k] - m2[i - 1, j, k]) * inv_dlat * inv_dlon

                dtx_dmg_x[i, j, k] = (m1[i, j + 1, k] - m1[i, j - 1, k]) * inv_dlon * inv_dz
                dtx_dmg_y[i, j, k] = (m1[i + 1, j, k] - m1[i - 1, j, k]) * inv_dlat * inv_dz
                dtx_dmg_z[i, j, k] = (m1[i + 1, j, k] - m1[i - 1, j, k]) * inv_dlat * inv_dlon

    return dtx_dms_x, dtx_dms_y, dtx_dms_z, dtx_dmg_x, dtx_dmg_y, dtx_dmg_z


def solve_least_squares(A, B):
    result = lsmr(A, B)
    return result[0]


def compute_block_scale(*arrays):
    # Normalize each cross-gradient block so it can numerically compete
    # with the identity blocks after using real km spacing.
    values = np.concatenate([np.ravel(np.asarray(arr, dtype=float)) for arr in arrays])
    nonzero_values = values[np.abs(values) > 0]
    target = nonzero_values if nonzero_values.size > 0 else values
    scale = np.sqrt(np.mean(target ** 2))
    return scale if np.isfinite(scale) and scale > 0 else 1.0


def summarize_update_change(delta_new, delta_old):
    diff = delta_new - delta_old
    mean_abs_diff = np.mean(np.abs(diff))
    max_abs_diff = np.max(np.abs(diff))
    rms_old = np.sqrt(np.mean(delta_old ** 2))
    rms_diff = np.sqrt(np.mean(diff ** 2))
    rel_rms_change = rms_diff / rms_old if rms_old > 0 else 0.0
    return mean_abs_diff, max_abs_diff, rel_rms_change


def main():
    file1 = "data/delta_ms0.dat"
    file2 = "data/delta_mg0.dat"
    file3 = "data/mod_iter0.dat"
    file4 = "data/joint_mod_iter0.dat"

    data1 = np.loadtxt(file1)
    data2 = np.loadtxt(file2)
    data3 = np.loadtxt(file3)
    data4 = np.loadtxt(file4)

    ms_y1, ms_x1, ms_z1, ms_v1 = data3[:, 0], data3[:, 1], data3[:, 2], data3[:, 3]
    mg_y1, mg_x1, mg_z1, mg_v1 = data4[:, 0], data4[:, 1], data4[:, 2], data4[:, 3]

    lat_values_deg = ordered_unique(ms_x1)
    lon_values_deg = ordered_unique(ms_y1)
    depth_values_km = ordered_unique(ms_z1)

    nx = len(lat_values_deg)
    ny = len(lon_values_deg)
    nz = len(depth_values_km)

    ms_0 = ms_v1.reshape((nx, ny, nz), order="F")
    mg_0 = mg_v1.reshape((nx, ny, nz), order="F")

    # Build real grid coordinates so the finite differences follow the
    # physical spacing of the model grid.
    lat_km, lon_km, depth_km, mean_lat = build_grid_coordinates(
        lat_values_deg,
        lon_values_deg,
        depth_values_km,
    )

    # Compute the cross-gradient residual tau = grad(ms) x grad(mg).
    tx0, ty0, tz0 = central_difference(ms_0, mg_0, lat_km, lon_km, depth_km)

    # Approximate the Jacobian blocks d(tau)/d(ms) and d(tau)/d(mg)
    # using the same centered finite-difference stencil.
    dtx_dms_x, dtx_dms_y, dtx_dms_z, dtx_dmg_x, dtx_dmg_y, dtx_dmg_z = calculate_gradient_derivatives(
        ms_0,
        mg_0,
        lat_km,
        lon_km,
        depth_km,
    )

    tx0_col = tx0.flatten(order="F")
    ty0_col = ty0.flatten(order="F")
    tz0_col = tz0.flatten(order="F")

    dtx_dms_x_col = dtx_dms_x.flatten(order="F")
    dtx_dms_y_col = dtx_dms_y.flatten(order="F")
    dtx_dms_z_col = dtx_dms_z.flatten(order="F")
    dtx_dmg_x_col = dtx_dmg_x.flatten(order="F")
    dtx_dmg_y_col = dtx_dmg_y.flatten(order="F")
    dtx_dmg_z_col = dtx_dmg_z.flatten(order="F")

    alpha_s = ALPHA_S
    alpha_g = ALPHA_G
    beta_t = BETA_T

    n = len(data1[:, 3])
    I = eye(n, format="csr")

    Delta_m_s0 = data1[:, 3]
    Delta_m_g0 = data2[:, 3]

    norm_s = np.mean(np.abs(Delta_m_s0))
    norm_g = np.mean(np.abs(Delta_m_g0))

    print("-" * 40)
    print("DEBUG: Mean latitude used for lon->km conversion: {:.3f}".format(mean_lat))
    print("DEBUG: dlat spacing (km): {:.3f}".format(np.mean(np.abs(np.diff(lat_km)))))
    print("DEBUG: dlon spacing (km): {:.3f}".format(np.mean(np.abs(np.diff(lon_km)))))
    print("DEBUG: dz spacing (km): {}".format(", ".join("{:.1f}".format(v) for v in np.abs(np.diff(depth_km)))))
    print("DEBUG: Surface Wave Gradient Magnitude (Mean Abs): {:.6e}".format(norm_s))
    print("DEBUG: Gravity Gradient Magnitude      (Mean Abs): {:.6e}".format(norm_g))

    if norm_g > 0:
        ratio = norm_s / norm_g
        print("DEBUG: Suggested Scaling Factor for Gravity: {:.2f}".format(ratio))
    else:
        print("DEBUG: Gravity gradient is practically ZERO.")

    # Each directional cross-gradient block is normalized by its own RMS scale.
    # This keeps the real-spacing version physically interpretable while
    # preventing the tau rows from becoming numerically negligible.
    scale_x = compute_block_scale(dtx_dms_x_col, dtx_dmg_x_col, tx0_col[:n])
    scale_y = compute_block_scale(dtx_dms_y_col, dtx_dmg_y_col, ty0_col[:n])
    scale_z = compute_block_scale(dtx_dms_z_col, dtx_dmg_z_col, tz0_col[:n])

    print("CONFIG: cross-gradient joint inversion parameters")
    print("CONFIG: alpha_s = {:.6f}".format(alpha_s))
    print("CONFIG: alpha_g = {:.6f}".format(alpha_g))
    print("CONFIG: beta_t  = {:.6f}".format(beta_t))
    print(
        "DEBUG: cross-gradient normalization scales: x={:.6e}, y={:.6e}, z={:.6e}".format(
            scale_x,
            scale_y,
            scale_z,
        )
    )
    print("-" * 40)
    sys.stdout.flush()

    I_s = I * alpha_s
    I_g = I * alpha_g

    dtx_dms_x_diag = diags(beta_t * (dtx_dms_x_col / scale_x))
    dtx_dmg_x_diag = diags(beta_t * (dtx_dmg_x_col / scale_x))
    dtx_dms_y_diag = diags(beta_t * (dtx_dms_y_col / scale_y))
    dtx_dmg_y_diag = diags(beta_t * (dtx_dmg_y_col / scale_y))
    dtx_dms_z_diag = diags(beta_t * (dtx_dms_z_col / scale_z))
    dtx_dmg_z_diag = diags(beta_t * (dtx_dmg_z_col / scale_z))

    A = bmat(
        [
            [I_s, None],
            [None, I_g],
            [dtx_dms_x_diag, dtx_dmg_x_diag],
            [dtx_dms_y_diag, dtx_dmg_y_diag],
            [dtx_dms_z_diag, dtx_dmg_z_diag],
        ],
        format="csr",
    )

    B = np.concatenate(
        [
            alpha_s * Delta_m_s0,
            alpha_g * Delta_m_g0,
            -beta_t * (tx0_col[:n] / scale_x),
            -beta_t * (ty0_col[:n] / scale_y),
            -beta_t * (tz0_col[:n] / scale_z),
        ]
    )

    X = solve_least_squares(A, B)

    Delta_m_s = X[:n]
    Delta_m_g = X[n:]

    mean_abs_diff_s, max_abs_diff_s, rel_rms_change_s = summarize_update_change(
        Delta_m_s,
        Delta_m_s0,
    )
    mean_abs_diff_g, max_abs_diff_g, rel_rms_change_g = summarize_update_change(
        Delta_m_g,
        Delta_m_g0,
    )

    print("DEBUG: mean(|Delta_m_s - Delta_m_s0|) = {:.6e}".format(mean_abs_diff_s))
    print("DEBUG: max(|Delta_m_s - Delta_m_s0|)  = {:.6e}".format(max_abs_diff_s))
    print("DEBUG: rel_rms_change_s               = {:.6e}".format(rel_rms_change_s))
    print("DEBUG: mean(|Delta_m_g - Delta_m_g0|) = {:.6e}".format(mean_abs_diff_g))
    print("DEBUG: max(|Delta_m_g - Delta_m_g0|)  = {:.6e}".format(max_abs_diff_g))
    print("DEBUG: rel_rms_change_g               = {:.6e}".format(rel_rms_change_g))
    sys.stdout.flush()

    ms_v2 = ms_v1 + Delta_m_s
    mg_v2 = mg_v1 + Delta_m_g

    ms_data = np.column_stack((ms_y1, ms_x1, ms_z1, ms_v2))
    np.savetxt("results/mod_iter.dat", ms_data, fmt="%f")

    mg_data = np.column_stack((mg_y1, mg_x1, mg_z1, mg_v2))
    np.savetxt("results/joint_mod_iter.dat", mg_data, fmt="%f")

    print("Joint inversion completed successfully.")


if __name__ == "__main__":
    main()
