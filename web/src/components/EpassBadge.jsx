import mark from '../design/epass-mark.json';

// Product-approved tonal and rounded refinement; geometry is shared with Flutter.
export function EpassBadge({ size = 32 }) {
  return <svg viewBox={mark.viewBox} width={size} height={size} aria-hidden="true" className="epass-product-badge">
    {mark.layers.map((layer, index) => {
      const color = `var(--r-semantic-color-${layer.role})`;
      return layer.type === 'rect'
        ? <rect key={index} x={layer.x} y={layer.y} width={layer.width} height={layer.height} rx={layer.rx} fill={layer.stroke ? 'none' : color} stroke={layer.stroke ? color : undefined} strokeWidth={layer.stroke} opacity={layer.opacity} />
        : <path key={index} d={layer.commands.map((c) => c.join(' ')).join(' ')} fill={color} opacity={layer.opacity} />;
    })}
  </svg>;
}
