# tesht assertion wishlist

Patterns observed in update-env_test.bash that would reduce boilerplate.

## tesht.AssertRC (exists)

Already provided. Used 8 times. Covers `(( rc == wantRc ))` pattern.

## tesht.AssertGot (exists)

Already provided. Used 8 times. Covers exact string equality.

## tesht.AssertContains -- pattern match

Most common hand-rolled assertion (30+ instances):

```bash
# current
[[ $got == *"expected substring"* ]] || {
  echo "should contain 'expected substring', got: $got"; return 1
}

# proposed
tesht.AssertContains "$got" "expected substring"
```

Would also handle negation:
```bash
# current
[[ $got != *"unexpected"* ]] || {
  echo "should not contain 'unexpected', got: $got"; return 1
}

# proposed
tesht.AssertNotContains "$got" "unexpected"
```

## tesht.AssertFile -- file existence

Used in file-deploying task tests:

```bash
# current
[[ -f "$dir/dst" ]] || { echo "dst missing"; return 1; }
[[ ! -f "$dir/dst.pub" ]] || { echo "dst.pub should not exist"; return 1; }

# proposed
tesht.AssertFile "$dir/dst"
tesht.AssertNoFile "$dir/dst.pub"
```

## tesht.AssertPerms -- file permission check

Used in file-deploying task tests:

```bash
# current
local privPerms=$(stat -c %a "$dir/dst")
[[ $privPerms == 600 ]] || { echo "dst perms=$privPerms, want=600"; return 1; }

# proposed
tesht.AssertPerms "$dir/dst" 600
```

## tesht.AssertEmpty / tesht.AssertNotEmpty

Used in validation tests:

```bash
# current
[[ -z $got ]] || { echo "want empty, got: $got"; return 1; }
[[ -n "$got" ]] || { echo "got empty, want non-empty"; return 1; }

# proposed
tesht.AssertEmpty "$got"
tesht.AssertNotEmpty "$got"
```

## Priority

By frequency of use:
1. tesht.AssertContains / tesht.AssertNotContains (30+)
2. tesht.AssertFile / tesht.AssertNoFile (10+)
3. tesht.AssertEmpty / tesht.AssertNotEmpty (5+)
4. tesht.AssertPerms (3)
