```shell
$ brew install openssl
$ ../configure \
    --prefix="${HOME}/.rubies/ruby-master" \
    --disable-install-doc \
    --with-openssl-dir=$(brew --prefix openssl@3)
```

```
Configuration summary for ruby version 3.3.0

   * Installation prefix: /Users/Alex/.rubies/ruby-master
   * exec prefix:         ${prefix}
   * arch:                arm64-darwin22
   * site arch:           ${arch}
   * RUBY_BASE_NAME:      ruby
   * ruby lib prefix:     ${libdir}/${RUBY_BASE_NAME}
   * site libraries path: ${rubylibprefix}/${sitearch}
   * vendor path:         ${rubylibprefix}/vendor_ruby
   * target OS:           darwin22
   * compiler:            clang
   * with thread:         pthread
   * with coroutine:      arm64
   * enable shared libs:  no
   * dynamic library ext: bundle
   * CFLAGS:              -fdeclspec ${optflags} ${debugflags} ${warnflags}
   * LDFLAGS:             -L. -fstack-protector-strong
   * DLDFLAGS:            -Wl,-multiply_defined,suppress
   * optflags:            -O3 -fno-fast-math
   * debugflags:          -ggdb3
   * warnflags:           -Wall -Wextra -Wextra-tokens \
                          -Wdeprecated-declarations -Wdivision-by-zero \
                          -Wdiv-by-zero -Wimplicit-function-declaration \
                          -Wimplicit-int -Wmisleading-indentation \
                          -Wpointer-arith -Wshorten-64-to-32 \
                          -Wwrite-strings -Wold-style-definition \
                          -Wmissing-noreturn -Wno-cast-function-type \
                          -Wno-constant-logical-operand -Wno-long-long \
                          -Wno-missing-field-initializers \
                          -Wno-overlength-strings -Wno-parentheses-equality \
                          -Wno-self-assign -Wno-tautological-compare \
                          -Wno-unused-parameter -Wno-unused-value \
                          -Wunused-variable -Wundef
   * strip command:       strip -A -n
   * install doc:         no
   * MJIT support:        yes
   * YJIT support:        yes
   * man page type:       doc
   * BASERUBY -v:         ruby 3.2.0 (2022-12-25 revision a528908271) \
                          [arm64-darwin22]

---
```
