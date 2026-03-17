import Modal from './Modal';

const ConfirmDialog = ({
  isOpen,
  onClose,
  onConfirm,
  title = 'Confirmar',
  message,
  confirmText = 'Eliminar',
  cancelText = 'Cancelar',
}) => {
  const footer = (
    <div className="d-flex justify-end gap-2">
      <button className="btn btn--secondary" onClick={onClose} type="button">
        {cancelText}
      </button>
      <button className="btn btn--danger" onClick={onConfirm} type="button">
        {confirmText}
      </button>
    </div>
  );

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={title} footer={footer}>
      <p>{message}</p>
    </Modal>
  );
};

export default ConfirmDialog;
