# Adapted from: https://github.com/andrewdcampbell/seam-carving
import warnings

import numba
import numpy as np

warnings.filterwarnings("ignore", category=numba.NumbaWarning)


@numba.jit
def forward_energy(img):
    energy = np.zeros_like(img)
    m = np.zeros_like(img)

    U = np.roll(img, 1, axis=0)
    L = np.roll(img, 1, axis=1)
    R = np.roll(img, -1, axis=1)

    cU = np.abs(R - L)
    cL = np.abs(U - L) + cU
    cR = np.abs(U - R) + cU

    for i in range(1, img.shape[0]):
        mU = m[i - 1]
        mL = np.roll(mU, 1)
        mR = np.roll(mU, -1)

        mULR = np.array([mU, mL, mR])
        cULR = np.array([cU[i], cL[i], cR[i]])
        mULR += cULR

        argmins = np.argmin(mULR, axis=0)
        m[i] = np.choose(argmins, mULR)
        energy[i] = np.choose(argmins, cULR)
    return energy


@numba.jit
def remove_seam(img, mask):
    h, w = img.shape
    return img[mask].reshape((h, w - 1))


@numba.jit
def get_minimum_seam(img, mask):
    h, w = img.shape
    M = forward_energy(img)

    # note: the if here in the original code
    # slows the function considerably
    M[mask > 0] = 10e6

    # populate DP matrix
    dp = np.zeros_like(M, dtype=np.int)
    for i in range(1, h):
        for j in range(0, w):
            if j == 0:
                idx = np.argmin(M[i - 1, j : j + 2])
                dp[i, j] = idx + j
                min_energy = M[i - 1, idx + j]
            else:
                idx = np.argmin(M[i - 1, j - 1 : j + 2])
                dp[i, j] = idx + j - 1
                min_energy = M[i - 1, idx + j - 1]
            M[i, j] += min_energy

    # backtrack to find path
    backtrack = np.ones_like(img, dtype=np.bool)
    j = np.argmin(M[-1])
    for i in range(h - 1, -1, -1):
        backtrack[i, j] = False
        j = dp[i, j]
    return backtrack


def seams_removal(img, seams, mask):
    for _ in range(seams):
        backtrack = get_minimum_seam(img, mask=mask)
        img = remove_seam(img, backtrack)
        mask = remove_seam(mask, backtrack)
    return img
