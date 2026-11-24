-- =====================================================
-- DBA FASE 1: BACKUP DE OBJETOS (DDL) CON ORACLE DATA PUMP IMPORT
-- =====================================================
-- Extrae metadata de funciones, paquetes, procedimientos, vistas y tablas
-- del schema IT mediante Data Pump (impdp).
-- Se ejecuta desde el servidor de base de datos con usuario con permisos correspondientes.
--
-- EJECUCIÓN:
--   impdp \
--     content=metadata_only \
--     dumpfile=metadata_tables.dmp \
--     logfile=metadata_tables.log \
--     include=function,package,procedure,view \
--     directory=dpdumps \
--     schemas=it
-- =====================================================

impdp schemas=it content=metadata_only dumpfile=metadata_tables.dmp logfile=metadata_tables_imp.log include=view:\"\=\'nombre del objeto\'\" directory=dpdumps