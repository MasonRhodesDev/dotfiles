function emit(line) { print line; printed = 1; blank = line ~ /^[ \t]*$/ }

function flush(   i) { for (i = 1; i <= held; i++) emit(pending[i]); held = 0 }

function finish(   n, i, list) {
  n = split(substr(names[section], 2), list, SUBSEP)
  for (i = 1; i <= n; i++)
    if (!((section, list[i]) in done)) { emit(list[i] "=" want[section, list[i]]); done[section, list[i]] = 1 }
}

BEGIN {
  FS = "\n"
  while ((getline line < keys) > 0) {
    split(line, f, "\t")
    if (!(f[1] in declared)) { order[++sections] = f[1]; declared[f[1]] = 1 }
    if (!((f[1], f[2]) in want)) names[f[1]] = names[f[1]] SUBSEP f[2]
    want[f[1], f[2]] = f[3]
  }
  while ((getline line < last) > 0) { split(line, f, "\t"); wrote[f[1], f[2]] = f[3] }
  section = ""
}

/^[ \t]*\[[^]]*\][ \t]*$/ {
  finish()
  flush()
  section = $0
  sub(/^[ \t]*\[/, "", section)
  sub(/\][ \t]*$/, "", section)
  seen[section] = 1
  emit($0)
  next
}

/^[ \t]*$/ { pending[++held] = $0; next }

{
  flush()
  eq = index($0, "=")
  if (section != "" && eq > 1 && $0 !~ /^[ \t]*[#;]/) {
    key = substr($0, 1, eq - 1)
    gsub(/^[ \t]+|[ \t]+$/, "", key)
    value = substr($0, eq + 1)
    if ((section, key) in want) {
      if ((section, key) in done) next
      done[section, key] = 1
      emit(value == want[section, key] ? $0 : key "=" want[section, key])
      next
    }
    if ((section, key) in wrote && wrote[section, key] == value) next
  }
  emit($0)
}

END {
  finish()
  flush()
  for (i = 1; i <= sections; i++) {
    if (order[i] in seen) continue
    if (printed && !blank) emit("")
    section = order[i]
    emit("[" section "]")
    finish()
  }
}
