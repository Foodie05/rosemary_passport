// Generated from official React 0.4.0 CSS by scripts/sync_epass_tokens.py.
const epassLoadingStyles = r'''.rm-loading {
  position: relative;
  display: inline-block;
  width: var(--rm-component-loading-size-medium);
  height: calc(var(--rm-component-loading-size-medium) * 1.125);
  flex-shrink: 0;
  color: var(--rm-primary);
  vertical-align: middle;
  isolation: isolate;
  perspective: 120px;
  transform-style: preserve-3d;
}
.rm-loading[data-size="small"] {
  width: var(--rm-component-loading-size-small);
  height: calc(var(--rm-component-loading-size-small) * 19 / 17);
  color: inherit;
  perspective: 70px;
}
.rm-loading[data-size="large"] {
  width: var(--rm-component-loading-size-large);
  height: calc(var(--rm-component-loading-size-large) * 1.125);
  perspective: 180px;
}
.rm-fold-back,
.rm-fold-front {
  display: block;
  position: absolute;
  top: 8%;
  width: 38%;
  height: 84%;
  background: currentColor;
  backface-visibility: visible;
  transform-style: preserve-3d;
}
.rm-fold-back {
  left: 24%;
  clip-path: polygon(0 0, 100% 15%, 100% 100%, 0 85%);
  opacity: 0.4;
  z-index: 1;
  transform: rotateY(0deg);
  transform-origin: 100% 50%;
}
.rm-fold-front {
  left: 39%;
  clip-path: polygon(0 15%, 100% 0, 100% 85%, 0 100%);
  z-index: 2;
  transform: rotateY(0deg);
  transform-origin: 0 50%;
}
.rm-loading[data-active="true"] .rm-fold-back {
  animation:
    rm-card-back var(--rm-fold-cycle) ease-in-out infinite,
    rm-card-layer-back var(--rm-fold-cycle) steps(1, end) infinite;
}
.rm-loading[data-active="true"] .rm-fold-front {
  animation:
    rm-card-front var(--rm-fold-cycle) ease-in-out infinite,
    rm-card-layer-front var(--rm-fold-cycle) steps(1, end) infinite;
}
@keyframes rm-card-back {
  0%,
  100% {
    transform: rotateY(0deg);
    opacity: 0.4;
  }
  20% {
    transform: rotateY(-58deg);
  }
  45% {
    transform: rotateY(0deg);
    opacity: 0.67;
  }
  70% {
    transform: rotateY(58deg);
    opacity: 0.51;
  }
}
@keyframes rm-card-front {
  0%,
  100% {
    transform: rotateY(0deg);
    opacity: 1;
  }
  20% {
    transform: rotateY(58deg);
  }
  45% {
    transform: rotateY(0deg);
    opacity: 0.78;
  }
  70% {
    transform: rotateY(-58deg);
    opacity: 0.92;
  }
}
@keyframes rm-card-layer-back {
  0%,
  19.99% {
    z-index: 1;
  }
  20%,
  69.99% {
    z-index: 2;
  }
  70%,
  100% {
    z-index: 1;
  }
}
@keyframes rm-card-layer-front {
  0%,
  19.99% {
    z-index: 2;
  }
  20%,
  69.99% {
    z-index: 1;
  }
  70%,
  100% {
    z-index: 2;
  }
}

.rm-loading { --rm-component-loading-size-medium:24px; --rm-component-loading-size-small:17px; --rm-component-loading-size-large:40px; --rm-fold-cycle:1200ms; --rm-primary:var(--r-semantic-color-primary); }
.rm-loading[data-visible="false"] { display:none; }
html[data-document-hidden="true"] .rm-loading * { animation:none !important; }
''';
const epassLoadingMarkup =
    r'''<span id="approve-loader" class="rm-loading" data-size="small" data-active="false" data-visible="false" aria-hidden="true"><span class="rm-fold-back"></span><span class="rm-fold-front"></span></span>''';
