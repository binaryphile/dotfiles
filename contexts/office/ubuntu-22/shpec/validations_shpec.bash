source "$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")"/../bash/validation_functions.bash

set -o nounset

describe escape_items
  it "creates a quoted string from some items"; ( _shpec_failures=0
    escape_items 'one two' three
    assert equal 'one\ two three' "$__"
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end
end

describe get
  it "removes the leading whitespace from each line"; ( _shpec_failures=0
    get <<'    EOS'
      one
      two
    EOS
    assert equal $'one\ntwo' "$__"
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "doesn't remove leading whitespace in excess of the first line"; ( _shpec_failures=0
    get <<'    EOS'
      one
       two
    EOS
    assert equal $'one\n two' "$__"
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "doesn't touch a line which doesn't match the leading space"; ( _shpec_failures=0
    get <<'    EOS'
      one
     two
    EOS
    assert equal $'one\n     two' "$__"
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end
end

describe get_raw
  it "gets stdin in __"; ( _shpec_failures=0
    get_raw <<<sample
    assert equal sample "$__"
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "returns true"; ( _shpec_failures=0
    get_raw <<<sample
    assert equal 0 $?
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "gets a multiline string"; ( _shpec_failures=0
    get_raw <<<$'hey\nthere'
    assert equal $'hey\nthere' "$__"
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "preserves leading and trailing non-newline whitespace"; ( _shpec_failures=0
    get_raw <<<' sample '
    assert equal ' sample ' "$__"
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end
end

describe get_repr
  it "removes the leading whitespace from each line and changes newlines to spaces"; ( _shpec_failures=0
    get_repr <<'    EOS'
      one
      two
    EOS
    assert equal 'one two' "$__"
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "escapes whitespace"; ( _shpec_failures=0
    get_repr <<'    EOS'
      one
      two three
    EOS
    assert equal 'one two\ three' "$__"
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end
end

describe gsub
  it "substitutes one substring for another"; ( _shpec_failures=0
    gsub sample amp ing
    assert equal single "$__"
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end
end

describe includes
  it "detects if an array contains an element"; ( _shpec_failures=0
    get_repr <<'    EOS'
      one
      two three
      four
    EOS
    samples=$__
    includes "$samples" "two three"
    assert equal 0 $?
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end
end

describe includes_in_order
  it "detects if an array contains elements in order"; ( _shpec_failures=0
    get_repr <<'    EOS'
      one
      "two three"
      four
      five
    EOS
    samples=$__
    get_repr <<'    EOS'
      "two three"
      five
    EOS
    includes_in_order "$samples" "$__"
    assert equal 0 $?
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "detects if an array contains elements but not in order"; ( _shpec_failures=0
    get_repr <<'    EOS'
      one
      "two three"
      four
      five
    EOS
    samples=$__
    get_repr <<'    EOS'
      five
      "two three"
    EOS
    includes_in_order "$samples" "$__"
    assert unequal 0 $?
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "detects if an array doesn't contain an element"; ( _shpec_failures=0
    get_repr <<'    EOS'
      one
      "two three"
      four
      five
    EOS
    samples=$__
    includes_in_order "$samples" six
    assert unequal 0 $?
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end
end

describe path_repr
  it "renders a representation of the path"; ( _shpec_failures=0
    path_repr 'one:two three:four'
    assert equal 'one two\ three four' "$__"
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end
end

describe setting
  it "detects if a setting is on"; ( _shpec_failures=0
    set -o vi
    setting vi on
    assert equal 0 $?
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "detects if a setting isn't on"; ( _shpec_failures=0
    set +o vi
    setting vi on
    assert unequal 0 $?
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "detects if a setting is off"; ( _shpec_failures=0
    set +o vi
    setting vi off
    assert equal 0 $?
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "detects if a setting isn't off"; ( _shpec_failures=0
    set -o vi
    setting vi off
    assert unequal 0 $?
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end
end

describe substr
  it "detects if one string is a substring of another"; ( _shpec_failures=0
    substr abcd bc
    assert equal 0 $?
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end

  it "detects if one string isn't a substring of another"; ( _shpec_failures=0
    substr abcd gf
    assert unequal 0 $?
    return "$_shpec_failures" );: $(( _shpec_failures += $? ))
  end
end
