# Modificaciones a Stored Procedures - INSERT notificacionesConsolidadas

**Fecha:** 2026-03-20

**Total archivos procesados:** 68

**Total SPs modificados:** 53

**Total INSERTs agregados:** 102

## SPs Modificados

| SP | INSERTs Agregados | Origen |
|---|---|---|
| ccoSinPersonal | 2 | Estructura |
| pa_Cambio_Cargo | 1 | Cambios |
| pa_Cambio_RelacionLaboral | 1 | Cambios |
| pa_Cambio_cco | 1 | Cambios |
| pa_Errores_Bajas | 2 | Bajas |
| pa_JornadaMalCreada | 2 | Horarios |
| pa_PersonalActualizadoNA | 1 | Trabajadores |
| pa_TrabajadoresValidacion | 2 | Trabajadores |
| pa_Transferencias | 3 | Transferencias |
| pa_alertaPermisoEnfermedadConMarcajes | 1 | Ausencias |
| pa_aniversario | 2 | Aniversarios |
| pa_biometricos_inactivos | 2 | Biometricos |
| pa_calculosHorarios | 1 | Horarios |
| pa_cambiosEmpresasAP | 2 | Cambios |
| pa_cambiosFechasBajas | 1 | Bajas |
| pa_cambiosFechasBajasOLD | 1 | Bajas |
| pa_cargafamiliarimpuestoalarenta | 1 | Cargas Familiares |
| pa_cargasFamiliaresEstadoCivilConyugue | 2 | Cargas Familiares |
| pa_cargosgtesjefoprTiendasMal | 2 | Jerarquias |
| pa_colaboradores_expatriados | 3 | Trabajadores |
| pa_colaboradores_reingresos | 2 | Trabajadores |
| pa_cuentas_duplicadas | 2 | Cuentas Bancarias |
| pa_diferencias_usuarios_documentId | 2 | Trabajadores |
| pa_enfermedadconsecutiva | 4 | Ausencias |
| pa_enrolado_mas_un_cco | 2 | Biometricos |
| pa_enrolado_no_consta | 2 | Biometricos |
| pa_enviarDatosCCO | 2 | Estructura |
| pa_errorAusencia | 4 | Ausencias |
| pa_errorAusenciaMarcaje | 2 | Marcajes |
| pa_errorVacacionMarcaje | 2 | Vacaciones |
| pa_errorVacacionesGeneral | 2 | Vacaciones |
| pa_errorVacacionesGeneralDennis | 2 | Vacaciones |
| pa_erroresSolVacvsSolVacPre | 2 | Vacaciones |
| pa_erroresVacacionesSinDetalle | 2 | Vacaciones |
| pa_existemarcaje | 1 | Marcajes |
| pa_faltantecaja | 1 | Creditos Tienda |
| pa_fnjMarcaje | 2 | Marcajes |
| pa_mismojefe1y2 | 2 | Jerarquias |
| pa_notificacionBiometrico | 1 | Biometricos |
| pa_permisosconsecutivos | 4 | Ausencias |
| pa_trabVariasEmpresasJerDif | 2 | Trabajadores |
| pa_trabajadoresCreados | 1 | Trabajadores |
| pa_trabajadoresHorariosCostoHorario | 3 | Horarios |
| pa_trabajadoresHorariosCostoHorario05092022 | 3 | Horarios |
| pa_transferencias_vencidas | 2 | Transferencias |
| pa_usuarioIngresoCumplea | 2 | Aniversarios |
| pa_usuarios_sin_datos | 2 | Trabajadores |
| pa_usuarios_sin_datosBiometricos | 2 | Trabajadores |
| pa_vacaciones_pasantes | 2 | Vacaciones |
| pa_validarJerarquiasCarNoPlanta | 2 | Jerarquias |
| pa_validarJerarquiasCarPlanta | 2 | Jerarquias |
| pa_validarJerarquiasLocales | 2 | Jerarquias |
| pa_validarMarcajes_correo | 1 | Marcajes |

## SPs NO Modificados (sin sp_send_dbmail activo)

| SP | Motivo |
|---|---|
| pa_ConsultaAvisosTiendasCCO | No contiene sp_send_dbmail |
| pa_avisos_biometricosDiel | No contiene sp_send_dbmail |
| pa_avisos_cargasFamiliares | No contiene sp_send_dbmail |
| pa_avisos_jerarquias2 | No contiene sp_send_dbmail |
| pa_avisos_problemas_marcajes_horarios | No contiene sp_send_dbmail |
| pa_correo_avisos_varios | No contiene sp_send_dbmail |
| pa_creditosPrtvsSinCupon | No contiene sp_send_dbmail |
| pa_diferencias_he_a_hea | No contiene sp_send_dbmail |
| pa_errorVacacionesGeneralDennisRepara | sp_send_dbmail comentado con -- (no activo) |
| pa_fechas_calendario | No contiene sp_send_dbmail |
| pa_llenarAvisosTiendas | No contiene sp_send_dbmail |
| pa_trabMenos2Benf | sp_send_dbmail comentado con -- (no activo) |
| pa_trabVarEmpCorreosDif | sp_send_dbmail comentado con -- (no activo) |
| pa_trabajadoresVariasEmpresasDifCargo | sp_send_dbmail comentado con -- (no activo) |
| pa_vacacionesPtosE3 | No contiene sp_send_dbmail |

## Notas y Casos Especiales

- **pa_errorVacacionesGeneralDennisRepara**: Tiene sp_send_dbmail comentado con `--`, no se modifico.
- **pa_trabajadoresVariasEmpresasDifCargo**: Tiene sp_send_dbmail comentado con `--`, no se modifico.
- **pa_trabMenos2Benf**: Tiene sp_send_dbmail comentado con `--`, no se modifico.
- **pa_trabVarEmpCorreosDif**: Tiene sp_send_dbmail comentado con `--`, no se modifico.
- **pa_aniversario**: Se agregaron bloques `BEGIN/END` alrededor de INSERT+EXEC dentro de un `IF/ELSE` sin `BEGIN/END`, para evitar que el INSERT rompa la logica condicional del SQL.
- Los SPs con multiples llamadas a sp_send_dbmail (cursores, bloques IF/ELSE) tienen un INSERT antes de cada llamada.
- El campo `cantidadRegistros` se mapea cuando existe una variable con COUNT o @@ROWCOUNT cercana al sp_send_dbmail (ej: @w, @c1, @c2, @cont_ausencias, @tiene1, @CONT, etc.).
- Los campos `periodoInicio` y `periodoFin` se mapean cuando existen variables de fecha de periodo en el SP (@fecha_ini/@fecha_fin, @fi/@ff, @fechaIni/@fechaFin).
- Los campos `fechaEnvio`, `fechaResolucion`, `fechaModificacion`, `usuarioResolucion`, `notasResolucion` y `descripcion` se dejan como NULL al insertar.
- El campo `estado` siempre se inserta como `'A'`.
- El campo `idNotificacion` es IDENTITY y `fechaCreacion` tiene DEFAULT GETDATE(), ambos se generan automaticamente.
- Cuando el sp_send_dbmail usa `@blind_copy_recipients`, se mapea a `destinatariosCc` (caso: pa_cambiosEmpresasAP).
- Cuando el sp_send_dbmail usa `@copy_recipients`, se mapea a `destinatariosCc` (caso: pa_cambiosFechasBajas, pa_cambiosFechasBajasOLD, pa_cargosgtesjefoprTiendasMal, pa_existemarcaje, pa_faltantecaja, pa_mismojefe1y2, pa_trabVariasEmpresasJerDif, pa_validarJerarquias*, etc.).
