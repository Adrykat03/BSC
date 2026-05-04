import { useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Filter, Search, X } from 'lucide-react';
import './ColumnFilterDropdown.css';

const POPOVER_WIDTH = 280;
const POPOVER_MAX_HEIGHT = 420;
const POPOVER_GAP = 4;

/**
 * Filtro estilo Excel: botón con icono que abre un popover con la lista
 * de valores únicos de la columna y permite seleccionar uno o varios.
 *
 * Props:
 * - field: identificador de columna ('title' | 'assignedTo' | 'leader' | 'status')
 * - label: texto descriptivo (solo para aria-label / título del popover)
 * - selected: Set<string> de valores actualmente seleccionados (los aplicados)
 * - onApply: (Set<string>) => void  — callback cuando se aplica la selección
 * - loadOptions: () => Promise<string[]>  — fetch lazy de valores únicos
 *
 * El popover guarda un draft local; sólo se aplica al hacer click en "Aplicar"
 * o al cerrarlo con Enter sobre el buscador.
 */
const ColumnFilterDropdown = ({ field, label, selected, onApply, loadOptions }) => {
  const [open, setOpen] = useState(false);
  const [options, setOptions] = useState(null); // null = no cargadas
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState('');
  const [draft, setDraft] = useState(new Set(selected || []));
  const [popoverPos, setPopoverPos] = useState(null); // { top, left }
  const triggerRef = useRef(null);
  const popoverRef = useRef(null);
  const searchInputRef = useRef(null);

  const computePosition = () => {
    const el = triggerRef.current;
    if (!el) return null;
    const rect = el.getBoundingClientRect();
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    let left = rect.left;
    if (left + POPOVER_WIDTH > vw - 8) left = Math.max(8, vw - POPOVER_WIDTH - 8);
    let top = rect.bottom + POPOVER_GAP;
    if (top + POPOVER_MAX_HEIGHT > vh - 8) {
      // Si no cabe abajo, abrir hacia arriba.
      top = Math.max(8, rect.top - POPOVER_MAX_HEIGHT - POPOVER_GAP);
    }
    return { top, left };
  };

  // Cuando se abre y no hay opciones cargadas, las trae.
  useEffect(() => {
    if (!open) return;
    setDraft(new Set(selected || []));
    setSearch('');
    setPopoverPos(computePosition());
    if (options == null) {
      setLoading(true);
      setError(null);
      loadOptions()
        .then((vals) => setOptions(Array.isArray(vals) ? vals : []))
        .catch((err) => setError(err?.message || 'Error al cargar opciones'))
        .finally(() => setLoading(false));
    }
    // Foco en el buscador al abrir
    setTimeout(() => searchInputRef.current?.focus(), 50);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  // Reposicionar al hacer scroll/resize mientras está abierto.
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

  // Cierre al click fuera (considera tanto el trigger como el popover en portal).
  useEffect(() => {
    if (!open) return;
    const onClick = (e) => {
      if (triggerRef.current && triggerRef.current.contains(e.target)) return;
      if (popoverRef.current && popoverRef.current.contains(e.target)) return;
      setOpen(false);
    };
    const onKey = (e) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onClick);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const filteredOptions = useMemo(() => {
    if (!options) return [];
    const q = search.trim().toLowerCase();
    if (!q) return options;
    return options.filter((v) => String(v).toLowerCase().includes(q));
  }, [options, search]);

  const allFilteredSelected = useMemo(() => {
    if (filteredOptions.length === 0) return false;
    return filteredOptions.every((v) => draft.has(v));
  }, [filteredOptions, draft]);

  const toggleValue = (val) => {
    setDraft((prev) => {
      const next = new Set(prev);
      if (next.has(val)) next.delete(val); else next.add(val);
      return next;
    });
  };

  const toggleAll = () => {
    setDraft((prev) => {
      const next = new Set(prev);
      if (allFilteredSelected) {
        filteredOptions.forEach((v) => next.delete(v));
      } else {
        filteredOptions.forEach((v) => next.add(v));
      }
      return next;
    });
  };

  const clearAll = () => setDraft(new Set());

  const apply = () => {
    onApply(new Set(draft));
    setOpen(false);
  };

  const hasSelection = (selected?.size || 0) > 0;

  const popover = open && popoverPos ? (
    <div
      ref={popoverRef}
      className="cfd__popover"
      role="dialog"
      style={{
        position: 'fixed',
        top: popoverPos.top,
        left: popoverPos.left,
        width: POPOVER_WIDTH,
        maxHeight: POPOVER_MAX_HEIGHT,
      }}
      onMouseDown={(e) => e.stopPropagation()}
      onClick={(e) => e.stopPropagation()}
    >
      <div className="cfd__popover-header">
        <Search size={14} aria-hidden="true" className="cfd__search-icon" />
        <input
          ref={searchInputRef}
          type="text"
          className="cfd__search"
          placeholder="Buscar..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); apply(); } }}
          aria-label="Buscar dentro de las opciones"
        />
        {search && (
          <button
            type="button"
            className="cfd__search-clear"
            onClick={() => setSearch('')}
            aria-label="Limpiar búsqueda"
          >
            <X size={12} />
          </button>
        )}
      </div>

      <div className="cfd__popover-actions">
        <label className="cfd__row cfd__row--all">
          <input
            type="checkbox"
            checked={allFilteredSelected}
            onChange={toggleAll}
            disabled={loading || filteredOptions.length === 0}
          />
          <span className="cfd__row-label">
            {allFilteredSelected ? 'Quitar todos' : 'Seleccionar todos'}
          </span>
        </label>
        <button
          type="button"
          className="cfd__link"
          onClick={clearAll}
          disabled={draft.size === 0}
        >
          Limpiar
        </button>
      </div>

      <div className="cfd__list">
        {loading && <div className="cfd__msg">Cargando…</div>}
        {error && <div className="cfd__msg cfd__msg--error">{error}</div>}
        {!loading && !error && filteredOptions.length === 0 && (
          <div className="cfd__msg">Sin opciones</div>
        )}
        {!loading && !error && filteredOptions.map((val) => (
          <label key={val} className="cfd__row">
            <input
              type="checkbox"
              checked={draft.has(val)}
              onChange={() => toggleValue(val)}
            />
            <span className="cfd__row-label" title={val}>{val}</span>
          </label>
        ))}
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
  ) : null;

  return (
    <span className="cfd">
      <button
        ref={triggerRef}
        type="button"
        className={`cfd__toggle ${hasSelection ? 'cfd__toggle--active' : ''}`}
        onClick={(e) => { e.stopPropagation(); setOpen((o) => !o); }}
        data-tooltip={`Filtrar ${label || field}`}
        aria-label={`Filtrar por ${label || field}`}
        aria-expanded={open}
      >
        <Filter size={14} aria-hidden="true" />
        {hasSelection && <span className="cfd__badge">{selected.size}</span>}
      </button>
      {popover && createPortal(popover, document.body)}
    </span>
  );
};

export default ColumnFilterDropdown;
