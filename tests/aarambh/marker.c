/*
 * Test stand-in for a boot loader. It writes a marker file to the volume it was
 * started from, then shuts the virtual machine down. The harness checks which
 * volume got the marker, which shows which loader Aarambh started.
 *
 * Built with -DMARKER_NAME=L"..." so one source serves every fixture. Build it
 * with the same flags as the real loader (see run.sh): a gnu-efi app compiled
 * without them misbehaves in the firmware.
 */

#include <efi.h>
#include <efilib.h>

#ifndef MARKER_NAME
#define MARKER_NAME L"MARKER.TXT"
#endif

EFI_STATUS efi_main(EFI_HANDLE image, EFI_SYSTEM_TABLE *systab)
{
    EFI_LOADED_IMAGE *loaded;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *fs;
    EFI_FILE_PROTOCOL *root;
    EFI_FILE_PROTOCOL *file;
    EFI_STATUS status;
    CHAR8 text[] = "started\n";
    UINTN size = sizeof(text) - 1;

    InitializeLib(image, systab);

    status = uefi_call_wrapper(BS->HandleProtocol, 3, image, &LoadedImageProtocol, (void **)&loaded);
    if (EFI_ERROR(status)) {
        return status;
    }

    status = uefi_call_wrapper(BS->HandleProtocol, 3, loaded->DeviceHandle,
                               &FileSystemProtocol, (void **)&fs);
    if (EFI_ERROR(status)) {
        return status;
    }

    status = uefi_call_wrapper(fs->OpenVolume, 2, fs, &root);
    if (EFI_ERROR(status)) {
        return status;
    }

    status = uefi_call_wrapper(root->Open, 5, root, &file, MARKER_NAME,
                               EFI_FILE_MODE_CREATE | EFI_FILE_MODE_READ | EFI_FILE_MODE_WRITE, 0);
    if (EFI_ERROR(status)) {
        return status;
    }

    uefi_call_wrapper(file->Write, 3, file, &size, text);
    uefi_call_wrapper(file->Flush, 1, file);
    uefi_call_wrapper(file->Close, 1, file);
    uefi_call_wrapper(root->Close, 1, root);

    uefi_call_wrapper(systab->RuntimeServices->ResetSystem, 4, EfiResetShutdown, EFI_SUCCESS, 0, NULL);

    return EFI_SUCCESS;
}
