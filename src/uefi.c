/* libguestfs
 * Copyright (C) 2009-2016 Red Hat Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

/**
 * Locations of UEFI files.
 */

#include <config.h>

#include <stdio.h>

/* NB: MUST NOT include "guestfs-internal.h". */
#include "guestfs-internal-frontend.h"

/* See src/appliance.c:guestfs_int_get_uefi. */
struct uefi_firmware
guestfs_int_ovmf_i386_firmware[] = {
  { NULL }
};

struct uefi_firmware
guestfs_int_ovmf_x86_64_firmware[] = {
  { "/usr/share/OVMF/OVMF_CODE.fd",
    NULL,
    "/usr/share/OVMF/OVMF_VARS.fd" },

  { "/usr/share/edk2/ovmf/OVMF_CODE.fd",
    NULL,
    "/usr/share/edk2/ovmf/OVMF_VARS.fd" },

  { NULL }
};

struct uefi_firmware
guestfs_int_aavmf_firmware[] = {
  { "/usr/share/AAVMF/AAVMF_CODE.fd",
    "/usr/share/AAVMF/AAVMF_CODE.verbose.fd",
    "/usr/share/AAVMF/AAVMF_VARS.fd" },

  { "/usr/share/edk2/aarch64/QEMU_EFI-pflash.raw",
    NULL,
    "/usr/share/edk2/aarch64/vars-template-pflash.raw" },

  { NULL }
};
