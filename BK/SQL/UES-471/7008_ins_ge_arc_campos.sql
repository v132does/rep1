begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_arc_campos (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, DESCRIPCION, TIP_DATO, FORMATO, POS_INICIAL, LONGITUD, POS_DECIMAL, CAMPO, FUNCION, SALTAR)
values ('REGISTRO_PLANES', 'GE_PLAN_DAS_TMP', 'BEXTER_GS.XLS', 1, 'Tipo de Documento', 'VARCHAR2', null, null, 7, null, 'tipo_documento', null, null);

insert into ge_arc_campos (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, DESCRIPCION, TIP_DATO, FORMATO, POS_INICIAL, LONGITUD, POS_DECIMAL, CAMPO, FUNCION, SALTAR)
values ('REGISTRO_PLANES', 'GE_PLAN_DAS_TMP', 'BEXTER_GS.XLS', 2, 'Número de documento', 'VARCHAR2', null, null, 21, null, 'nro_documento', null, null);

insert into ge_arc_campos (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, DESCRIPCION, TIP_DATO, FORMATO, POS_INICIAL, LONGITUD, POS_DECIMAL, CAMPO, FUNCION, SALTAR)
values ('REGISTRO_PLANES', 'GE_PLAN_DAS_TMP', 'BEXTER_GS.XLS', 3, 'Nombre', 'NUMBER', null, null, 100, null, 'NOMBRE', NULL, null);

insert into ge_arc_campos (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, DESCRIPCION, TIP_DATO, FORMATO, POS_INICIAL, LONGITUD, POS_DECIMAL, CAMPO, FUNCION, SALTAR)
values ('REGISTRO_PLANES', 'GE_PLAN_DAS_TMP', 'BEXTER_GS.XLS', 4, 'Monto', 'NUMBER', null, null, 18, null, 'MONTO', 'trunc($param)', null);

insert into ge_arc_campos (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, DESCRIPCION, TIP_DATO, FORMATO, POS_INICIAL, LONGITUD, POS_DECIMAL, CAMPO, FUNCION, SALTAR)
values ('REGISTRO_PLANES', 'GE_PLAN_DAS_TMP', 'BEXTER_GS.XLS', 5, 'Tipo de cuenta', 'VARCHAR2', null, null, 7, null, 'tipo_cuenta', null, null);

insert into ge_arc_campos (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, DESCRIPCION, TIP_DATO, FORMATO, POS_INICIAL, LONGITUD, POS_DECIMAL, CAMPO, FUNCION, SALTAR)
values ('REGISTRO_PLANES', 'GE_PLAN_DAS_TMP', 'BEXTER_GS.XLS', 6, 'Número de cuenta ', 'VARCHAR2', null, null, 16, null, 'nro_cuenta', null, null);

insert into ge_arc_campos (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, DESCRIPCION, TIP_DATO, FORMATO, POS_INICIAL, LONGITUD, POS_DECIMAL, CAMPO, FUNCION, SALTAR)
values ('REGISTRO_PLANES', 'GE_PLAN_DAS_TMP', 'BEXTER_GS.XLS', 7, 'Descripción del plan', 'VARCHAR2', null, null, 101, null, 'desc_plan', null, null);

insert into ge_arc_campos (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, DESCRIPCION, TIP_DATO, FORMATO, POS_INICIAL, LONGITUD, POS_DECIMAL, CAMPO, FUNCION, SALTAR)
values ('REGISTRO_PLANES', 'GE_PLAN_DAS_TMP', 'BEXTER_GS.XLS', 8, 'Fecha Inicio',
 'date', 'DD/MM/YYYY', null, 10, null,
  'fec_inicio', 'To_date($param,'||chr(39)||'DD/MM/YYYY'||chr(39)||')' , null);
  
insert into ge_arc_campos (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, DESCRIPCION, TIP_DATO, FORMATO, POS_INICIAL, LONGITUD, POS_DECIMAL, CAMPO, FUNCION, SALTAR)
values ('REGISTRO_PLANES', 'GE_PLAN_DAS_TMP', 'BEXTER_GS.XLS', 9, 'Fecha Fin',
 'date', 'DD/MM/YYYY', null, 10, null,
  'fec_fin', 'To_date($param,'||chr(39)||'DD/MM/YYYY'||chr(39)||')' , null);



commit;
