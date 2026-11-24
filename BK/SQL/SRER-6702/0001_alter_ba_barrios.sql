-- =============================================================================
-- Script  : 0001_alter_ba_barrios.sql
-- Ticket  : FIELDESK-164963 / Barrios BCP
-- Objeto  : IT.BA_BARRIOS
-- Autor   : Generado 2026-07-20
-- Orden   : Ejecutar antes de 0002 y 0003.
-- =============================================================================
-- Cambios:
--
--   MODIFY descripcion VARCHAR2(40) -> VARCHAR2(60)
--     Motivo: el archivo BCP trae descripciones de hasta 56 caracteres.
--             Con VARCHAR2(40) se truncarian 206 de 7.995 registros.
--             Widening puro: no requiere deshabilitar constraints ni tocar datos.
--
--   ADD ref_externa NUMBER(7)
--     Identificador externo BCP (max 7 digitos: DDDCCCBBB).
--     NO es el COD_BARRIO interno (correlativo local 1-9999 por ciudad).
--     Analogo a BA_CIUDADES.REF_EXTERNA.
--
--   ADD des_bco_central VARCHAR2(60)
--     Descripcion original del BCP con sufijo de zona embebido
--     (ej: "SAJONIA - URBANA"). Analogo a BA_CIUDADES.DES_BCO_CENTRAL.
--
--   ADD cod_tipo_zona VARCHAR2(1)
--     Tipo de zona resuelto contra dominio TIPO_ZONA_BARRIO de BA_COD_REFERENCIAS.
--     Valores: U=Urbana, R=Rural, S=Sub Urbana.
--     Distribucion BCP: Rural 5.666 / Urbana 2.230 / Sub Urbana 99.
--
--   CREATE INDEX IN_BARR_REF_EXTERNA (COD_PAIS, COD_CIUDAD, REF_EXTERNA)
--     Soporte al upsert de PRS_ACT_REF_BARRIOS para detectar vinculacion previa.
--
--   MODIFY cod_ciudad NUMBER(3) -> NUMBER(5)
--     EXCLUIDO de este script. No aplica para el frente Barrios.
--
-- Impacto: todos los cambios son ADITIVOS. Columnas nuevas NULLABLE.
--          El MODIFY de descripcion es widening puro (no rompe datos existentes).
-- =============================================================================

ALTER TABLE IT.BA_BARRIOS
  MODIFY (descripcion     VARCHAR2(60))
  ADD    (ref_externa     NUMBER(7),
          des_bco_central VARCHAR2(60),
          cod_tipo_zona   VARCHAR2(1));

CREATE INDEX IT.IN_BARR_REF_EXTERNA
  ON IT.BA_BARRIOS (COD_PAIS, COD_CIUDAD, REF_EXTERNA)
  TABLESPACE IT_IND
  PCTFREE 10
  INITRANS 2
  MAXTRANS 255
  STORAGE (
    INITIAL 64K
    NEXT 1M
    MINEXTENTS 1
    MAXEXTENTS UNLIMITED
  );

COMMENT ON COLUMN IT.BA_BARRIOS.descripcion
  IS 'Nombre del barrio (ampliado a 60 chars para cubrir descripciones BCP de hasta 56 chars).';

COMMENT ON COLUMN IT.BA_BARRIOS.ref_externa
  IS 'Codigo de referencia BCP del barrio (hasta 7 digitos: DDDCCCBBB). Analogo a BA_CIUDADES.REF_EXTERNA.';

COMMENT ON COLUMN IT.BA_BARRIOS.des_bco_central
  IS 'Descripcion del barrio segun catalogo BCP, incluyendo sufijo de zona (ej: SAJONIA - URBANA). Analogo a BA_CIUDADES.DES_BCO_CENTRAL.';

COMMENT ON COLUMN IT.BA_BARRIOS.cod_tipo_zona
  IS 'Tipo de zona: U=Urbana, R=Rural, S=Sub Urbana. Resuelto contra dominio TIPO_ZONA_BARRIO de BA_COD_REFERENCIAS.';
