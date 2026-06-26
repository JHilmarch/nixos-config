{inputs, ...}: {
  imports = [
    # Compose the non-NVIDIA parts of the upstream `lenovo-thinkpad-p51` module
    # directly. We avoid `inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p51`
    # because it pulls in the NVIDIA Prime/Maxwell stack, and the discrete GPU
    # is intentionally unused on this host.
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad
  ];

  # Kaby Lake (i7-7700HQ) i915 tuning. `common-cpu-intel-kaby-lake` is not
  # exported as a flake output and `common-gpu-intel-kaby-lake` is deprecated
  # (nixos-hardware#992), so the P51-specific values from that module are set
  # inline here to preserve upstream behaviour.
  boot.kernelParams = [
    "i915.enable_guc=2"
    "i915.enable_fbc=1"
    "i915.enable_psr=2"
  ];

  hardware.intelgpu = {
    computeRuntime = "legacy";
    vaapiDriver = "intel-media-driver";
  };
}
