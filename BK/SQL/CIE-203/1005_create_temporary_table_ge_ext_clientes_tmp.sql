-- Create table
create global temporary table IT.GE_EXT_CLIENTES_TMP
(
  cod_persona      VARCHAR2(10),
  fec_extracto     DATE,
  fre_extracto     VARCHAR2(1),
  funcionario      VARCHAR2(1),
  nom_cliente      VARCHAR2(120),
  direccion        VARCHAR2(90),
  telefono         VARCHAR2(16),
  cod_usu_oficial  VARCHAR2(10),
  cod_pais         NUMBER(3),
  cod_ciudad       NUMBER(3),
  tel_oficial      VARCHAR2(35),
  nro_interno      NUMBER(5),
  cod_extracto     NUMBER(3),
  det_direccion    VARCHAR2(50),
  observacion      VARCHAR2(50),
  barrio           VARCHAR2(40),
  cod_mensaje      NUMBER(2),
  nro_control      NUMBER(7),
  tip_impresion    VARCHAR2(1),
  usu_insercion    VARCHAR2(10) default SUBSTR(USER,1,10),
  fec_insercion    DATE default SYSDATE,
  usu_modificacion VARCHAR2(10) default SUBSTR(USER,1,10),
  fec_modificacion DATE default SYSDATE,
  cli_confidencial VARCHAR2(1),
  cod_oficina      NUMBER(3),
  cat_riesgo       VARCHAR2(1),
  fec_ult_clasif   DATE,
  cod_per_empresa  VARCHAR2(10)
)
on commit preserve rows;
-- Add comments to the table 
comment on table IT.GE_EXT_CLIENTES_TMP
  is 'Cabecera de Extracto Unico ** Mantener seis meses **';
-- Add comments to the columns 
comment on column IT.GE_EXT_CLIENTES_TMP.cod_persona
  is 'Codigo del Cliente.';
comment on column IT.GE_EXT_CLIENTES_TMP.fec_extracto
  is 'Fecha del Extracto.';
comment on column IT.GE_EXT_CLIENTES_TMP.fre_extracto
  is 'Frecuencia del Extracto ( D=diaria, S=semanal, M=mensual ).';
comment on column IT.GE_EXT_CLIENTES_TMP.funcionario
  is 'Cuenta de Funcionario (S=Si / N=No).';
comment on column IT.GE_EXT_CLIENTES_TMP.nom_cliente
  is 'Nombre del Cliente.';
comment on column IT.GE_EXT_CLIENTES_TMP.direccion
  is 'Direccion.';
comment on column IT.GE_EXT_CLIENTES_TMP.telefono
  is 'Numero de Telefono.';
comment on column IT.GE_EXT_CLIENTES_TMP.cod_usu_oficial
  is 'Codigo del Oficial de Cuenta.';
comment on column IT.GE_EXT_CLIENTES_TMP.cod_pais
  is 'Codigo de Pais.';
comment on column IT.GE_EXT_CLIENTES_TMP.cod_ciudad
  is 'Codigo de Ciudad.';
comment on column IT.GE_EXT_CLIENTES_TMP.tel_oficial
  is 'Telefono del Oficial de Cuenta.';
comment on column IT.GE_EXT_CLIENTES_TMP.nro_interno
  is 'Numero de Interno.';
comment on column IT.GE_EXT_CLIENTES_TMP.cod_extracto
  is 'Codigo de Extracto.';
comment on column IT.GE_EXT_CLIENTES_TMP.det_direccion
  is 'Detalle de la Direccion.';
comment on column IT.GE_EXT_CLIENTES_TMP.observacion
  is 'Observacion.';
comment on column IT.GE_EXT_CLIENTES_TMP.barrio
  is 'Nombre del Barrio.';
comment on column IT.GE_EXT_CLIENTES_TMP.cod_mensaje
  is 'Tipo de Mensaje.';
comment on column IT.GE_EXT_CLIENTES_TMP.nro_control
  is 'Numero de Control.';
comment on column IT.GE_EXT_CLIENTES_TMP.tip_impresion
  is 'Tipo de Impresion, Valores Posibles: C-Impreso,  Z-x Mail,  N-No impreso X-Envio x mail e impreso.';
comment on column IT.GE_EXT_CLIENTES_TMP.usu_insercion
  is 'Usuario que realizo la insercion del registro.';
comment on column IT.GE_EXT_CLIENTES_TMP.fec_insercion
  is 'Fecha en que se inserto el registro.';
comment on column IT.GE_EXT_CLIENTES_TMP.usu_modificacion
  is 'Usuario que realizo la ultima modificacion en el registro.';
comment on column IT.GE_EXT_CLIENTES_TMP.fec_modificacion
  is 'Fecha en que se realizo la ultima modificacion en el registro.';
comment on column IT.GE_EXT_CLIENTES_TMP.cli_confidencial
  is 'Indica si el cliente es confidencial (S/N.';
comment on column IT.GE_EXT_CLIENTES_TMP.cod_oficina
  is 'Oficina del cliente.';
comment on column IT.GE_EXT_CLIENTES_TMP.cat_riesgo
  is 'Categoria de Riesgo.';
comment on column IT.GE_EXT_CLIENTES_TMP.fec_ult_clasif
  is 'Fecha de ultima clasificacion o categorizacion.';
comment on column IT.GE_EXT_CLIENTES_TMP.cod_per_empresa
  is 'Codigo de persona de la empresa pagadora.';
-- Create/Recreate indexes 
create unique index IN_GECTM_COD_PERSONA on IT.GE_EXT_CLIENTES_TMP (COD_PERSONA, COD_EXTRACTO, FEC_EXTRACTO);
 
