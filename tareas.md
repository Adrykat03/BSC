las tareas deben actuar de la siguiente manera:

ROL: (Gerente)

Crea tareas, puede cambiar estados, puede descargar las evidencias. Al crear la tarea no se debe cargar la evidencia. Modifiquemos para cargar Insumos para la tarea como un campo adicional. tambien puede asignar personas y cambiar la asignación.

ROL: (Lider)

El lider puede ver tareas, no las puede eliminar, no puede crear tareas, puede descargar evidencias, será un rol de validación puede descargar y cambiar la evidencia, puede modificar tareas para cambiar por un titulo mas adecuado o una descripcion mas completa, puede cambiar los insumos de la tarea, puede asignar y cambiar asignacion de persona, puede cambiar de estado la tarea.

ROL: (Colaborador)

Puede observar las tareas que le han sido asignadas, no puede editar la tarea, puede cargar evidencias, no puede cambiar insumos, puede cambiar el estado.

Los estados y los cambios accesibles por rol son: Los colaboradores pueden ver las tareas en estado Asignadas, Completa - Por Validar, Reasignada.

Los estados que los lideres pueden tener es si una tarea esta Completa - Por validar, puede pasar a Reasignada nunca a Asignada nuevamente. Puede cambiar a Completa - Validada.

El Gerente puede ver todas las tareas, puede cambiar de Completa - Validada a Completa, o cambiar a Reasignada. Solamente puede asignar tareas a los colaboradores con rol de Lider.

Los ldieres deben ver las tareas Asignadas, o en estados diferentes a Completa, donde ellos han tenido participación. Esto implica que en el objeto tarea se debe llevar un array de los estados y los cambios que han tenido. De esta forma un lider puede ver las que el en algun momento recibio y las que asigno a los colaboradores.

Un lider puede asignar una tarea a cualquier colaborador.

Un lider no verá las tareas Completas ya aceptadas por el gerente.

El gerente puede ver todas las tareas y las asignaciones respectivas.

El gerente puede asignar a un Lider unicamente, y luego puede asignar a un Colaborador, no puede asignar a un colaborador directamente como paso 1.
