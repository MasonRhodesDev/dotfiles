{
  headless = { description = "fixture"; values = [ true false ]; };
  profile = { description = "fixture"; values = [ "work" "personal" ]; };
  form = { description = "fixture"; values = [ "laptop" "desktop" "server" ]; };
  gaming = { description = "fixture"; values = [ true false ]; default = false; };
  hardware = { description = "fixture"; values = [ "pad" ]; many = true; };
}
