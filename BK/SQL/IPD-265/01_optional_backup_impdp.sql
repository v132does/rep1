-- =====================================================
-- DBA FASE 1: BACKUP DE OBJETOS (DDL) CON ORACLE DATA PUMP IMPORT
-- =====================================================
-- Extrae metadata de funciones, paquetes, procedimientos y vistas
-- del schema IT mediante Data Pump (impdp).
-- Se ejecuta desde el servidor de base de datos con usuario con permisos correspondientes.
--
-- EJECUCIÓN:
--   impdp \
--     content=metadata_only \
--     dumpfile=metadata_functions.dmp \
--     logfile=metadata_functions.log \
--     include=function,package,procedure,view \
--     directory=dpdumps \
--     schemas=it
-- =====================================================

impdp schemas=it content=metadata_only dumpfile=metadata_functions.dmp logfile=metadata_functions_imp.log include=view:\"\=\'nombre del objeto\'\" directory=dpdumps