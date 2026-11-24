-- =====================================================
-- DBA FASE 1: BACKUP DE OBJETOS (DDL) CON ORACLE DATA PUMP EXPORT
-- =====================================================
-- Extrae metadata de funciones, paquetes, procedimientos y vistas
-- del schema IT mediante Data Pump (expdp).
-- Se ejecuta desde el servidor de base de datos con usuario con permisos correspondientes.
--
-- EJECUCIÓN:
--   expdp \
--     content=metadata_only \
--     dumpfile=metadata_types.dmp \
--     logfile=metadata_types.log \
--     include=function,package,procedure,view \
--     directory=dpdumps \
--     schemas=it
-- =====================================================

expdp content=metadata_only dumpfile=metadata_types.dmp logfile=metadata_types.log include=function,package,procedure,view directory=dpdumps schemas=it
