import { useEffect, useRef, useState } from 'react';
import './ColumnFilterDropdown.css';

const MONTHS = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

const POPOVER_WIDTH = 220;

/**
 * Selector múltiple de meses estilo dropdown con checkboxes.
 *
 * Props:
 * - selected: Set<string> con valores '1'..'12' actualmente aplicados
 * - onApply: (Set<string>) => void  — callback al hacer "Aplicar"
 * - tooltip?: string  — texto para data-tooltip del trigger
 */
const MonthMultiSelect = ({ selected, onApply, tooltip }) => {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState(new Set(selected || []));
  const [popoverPos, setPopoverPos] = useState(null);
  const triggerRef = useRef(null);
  const popoverRef = useRef(null);

  const computePosition = () => {
    const el = triggerRef.current;
    if (!el) return null;
    const rect = el.getBoundingClientRect();
    return { top: rect.bottom + 4, left: rect.left };
  };

  useEffect(() => {
    if (!open) return;
    setDraft(new Set(selected || []));
    setPopoverPos(computePosition());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const update = () => setPopoverPos(computePosition());
    window.addEventListener('scroll', update, true);
    window.addEventListener('resize', update);
    return () => {
      window.removeEventListener('scroll', update, true);
      window.removeEventListener('resize', update);
    };
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onClick = (e) => {
      if (triggerRef.current && triggerRef.current.contains(e.target)) return;
      if (popoverRef.current && popoverRef.current.contains(e.target)) return;
      setOpen(false);
    };
    const onKey = (e) => { if (e.key === 'Escape') setOpen(false); };
    document.addEventListener('mousedown', onClick);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onClick);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const toggleValue = (val) => {
    setDraft((prev) => {
      const next = new Set(prev);
      if (next.has(val)) next.delete(val); else next.add(val);
      return next;
    });
  };

  const allSelected = draft.size === 12;

  const toggleAll = () => {
    setDraft((prev) => {
      if (prev.size === 12) return new Set();
      return new Set(MONTHS.map((_, i) => String(i + 1)));
    });
  };

  const apply = () => {
    onApply(new Set(draft));
    setOpen(false);
  };

  const clear = () => setDraft(new Set());

  const buttonLabel = () => {
    const arr = Array.from(selected || []).map(Number).sort((a, b) => a - b);
    if (arr.length === 0) return 'Mes: Todos';
    if (arr.length === 12) return 'Mes: Todos';
    if (arr.length === 1) return `Mes: ${MONTHS[arr[0] - 1]}`;
    if (arr.length <= 3) return `Mes: ${arr.map((m) => MONTHS[m - 1].slice(0, 3)).join(', ')}`;
    return `Mes: ${arr.length} seleccionados`;
  };

  return (
    <>
      <button
        ref={triggerRef}
        type="button"
        className="form-control form-select"
        onClick={(e) => { e.stopPropagation(); setOpen((o) => !o); }}
        style={{
          width: '180px',
          height: '36px',
          padding: '0 32px 0 12px',
          fontSize: '13px',
          textAlign: 'left',
          cursor: 'pointer',
        }}
        data-tooltip={tooltip || 'Filtrar por mes (uno o varios)'}
        aria-label="Filtrar por mes"
        aria-expanded={open}
      >
        {buttonLabel()}
      </button>
      {open && popoverPos && (
        <div
          ref={popoverRef}
          className="cfd__popover"
          role="dialog"
          style={{
            position: 'fixed',
            top: popoverPos.top,
            left: popoverPos.left,
            width: POPOVER_WIDTH,
            maxHeight: 420,
          }}
          onMouseDown={(e) => e.stopPropagation()}
        >
          <div className="cfd__popover-actions">
            <label className="cfd__row cfd__row--all" style={{ padding: 0 }}>
              <input type="checkbox" checked={allSelected} onChange={toggleAll} />
              <span className="cfd__row-label">
                {allSelected ? 'Quitar todos' : 'Seleccionar todos'}
              </span>
            </label>
            <button
              type="button"
              className="cfd__link"
              onClick={clear}
              disabled={draft.size === 0}
            >
              Limpiar
            </button>
          </div>

          <div className="cfd__list">
            {MONTHS.map((nombre, idx) => {
              const val = String(idx + 1);
              return (
                <label key={val} className="cfd__row">
                  <input
                    type="checkbox"
                    checked={draft.has(val)}
                    onChange={() => toggleValue(val)}
                  />
                  <span className="cfd__row-label">{nombre}</span>
                </label>
              );
            })}
          </div>

          <div className="cfd__popover-footer">
            <button
              type="button"
              className="btn btn--secondary btn--sm"
              onClick={() => setOpen(false)}
            >
              Cancelar
            </button>
            <button
              type="button"
              className="btn btn--primary btn--sm"
              onClick={apply}
            >
              Aplicar
            </button>
          </div>
        </div>
      )}
    </>
  );
};

export default MonthMultiSelect;
