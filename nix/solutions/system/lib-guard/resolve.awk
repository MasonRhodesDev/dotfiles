function exists(path,   line, got) {
  got = (getline line < path)
  close(path)
  return got >= 0
}

function bracketed(text) {
  sub(/^[^[]*\[/, "", text)
  sub(/\][^]]*$/, "", text)
  return text
}

function resolve(name,   i, dir, origin) {
  if (name ~ /\//) return exists(name) ? name : ""
  origin = file
  sub(/\/[^\/]*$/, "", origin)
  for (i = 1; i <= ndirs; i++) {
    dir = dirs[i]
    gsub(/\$ORIGIN|\$\{ORIGIN\}/, origin, dir)
    if (exists(dir "/" name)) return dir "/" name
  }
  if ((name, bits) in cache) return cache[name, bits]
  dir = bits == 32 ? "/usr/lib32" : "/usr/lib"
  return exists(dir "/" name) ? dir "/" name : ""
}

function flush(   i, pkg, found) {
  if (file == "" || !(file in owner)) return
  pkg = owner[file]
  for (i = 1; i <= nneeded; i++) {
    found = resolve(needed[i])
    if (mode == "unresolved" && found == "" && !((pkg, needed[i]) in ships)) print pkg "\t" file "\t" needed[i]
    if (mode == "dropped" && found in dropped) print pkg "\t" file "\t" needed[i] "\t" found
  }
}

BEGIN {
  while ((getline line < cachefile) > 0) {
    if (line !~ / => /) continue
    sub(/^[[:space:]]+/, "", line)
    name = line
    sub(/ .*/, "", name)
    tag = line
    sub(/^[^(]*\(/, "", tag)
    sub(/\).*/, "", tag)
    path = line
    sub(/.* => /, "", path)
    width = tag ~ /64/ ? 64 : 32
    if (!((name, width) in cache)) cache[name, width] = path
  }
  close(cachefile)
  FS = "\t"
  while ((getline line < ownersfile) > 0) {
    split(line, field, "\t")
    owner[field[2]] = field[1]
    base = field[2]
    sub(/.*\//, "", base)
    ships[field[1], base] = 1
  }
  close(ownersfile)
  if (mode == "dropped") {
    while ((getline line < droppedfile) > 0) dropped[line] = 1
    close(droppedfile)
  }
  FS = " "
}

/^File: / { flush(); file = substr($0, 7); bits = 64; nneeded = 0; ndirs = 0; next }
/^  Class:/ { bits = $2 == "ELF32" ? 32 : 64; next }
/\(NEEDED\)/ { needed[++nneeded] = bracketed($0); next }
/\((RPATH|RUNPATH)\)/ { ndirs = split(bracketed($0), dirs, ":"); next }

END { flush() }
