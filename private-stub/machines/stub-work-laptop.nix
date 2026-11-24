{
  system = "x86_64-linux";
  traits = { headless = false; form = "laptop"; profile = "work"; secrets = "infisical"; uses = [ "dev" ]; hardware = [ "framework-16" "zsa-keyboard" ]; };
  user = { name = "alex"; home = "/home/alex"; };
  private.xwaylandPrimary = "EXAMPLE-MONITOR";
  private.softMixerNodes = [ "~alsa_output.usb-Example_Headset.*" ];
  private.internalPanel = "eDP-EXAMPLE";
  private.dgpuPci = "0000:ff:00.0";
  private.trustedNetworks = [ "example-home-wifi" ];
  private.networkZones = { "example-office-wifi" = "work"; };
  private.infisical = { projectId = "example-project"; environment = "example-env"; path = "/example-path"; };
  private.workMacServer = { tailnetAddress = "work-mac.example.invalid"; user = "alex"; };
  private.packages = [ "rbw" ];
  private.bedrock = {
    BEDROCK_AIP_SONNET = "arn:aws:bedrock:us-west-2:000000000000:application-inference-profile/example-sonnet";
    BEDROCK_AIP_OPUS = "arn:aws:bedrock:us-west-2:000000000000:application-inference-profile/example-opus";
    BEDROCK_AIP_HAIKU = "arn:aws:bedrock:us-west-2:000000000000:application-inference-profile/example-haiku";
  };
  private.buildHost = "build-host.example.invalid";
}
