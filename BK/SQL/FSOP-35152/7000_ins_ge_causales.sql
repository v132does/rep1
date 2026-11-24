begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (405, 'FALTA FIRMA LIBRADORA', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (406, 'NO CONCUERDA USO DE FIRMAS', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (407, 'FALTA SELLO DE LA RAZÓN SOCIAL', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (408, 'NO NEGOCIABLE, MAS DE 1 ENDOSO', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (409, 'TEXTO ENMENDADO', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (410, 'TEXTO INCOMPLETO', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (411, 'NO CONCUERDA TEXTO CON CIFRA', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (412, 'EXTRAVIO', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (413, 'SUSTRACCION', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (414, 'ORDEN JUDICIAL', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (415, 'DATOS INCOMPLETOS (FECHA/TEXTO)', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (416, 'MAS DE 180 DIAS ENTRE FECHAS', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (417, 'CHEQUE FORMATO ANTERIOR', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (418, 'IMAGEN NO NITIDA (UV/JGP)', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (419, 'DATOS DEL CHEQUE INCORRECTO', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (420, 'FECHA EMITIDA CON NUMEROS ROMANOS', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (421, 'CHEQUE CON SALVEDADES', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (422, 'CHEQUE ADULTERADO', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (423, 'INMOV. DE ACTIVOS FINANC.-LEY 6419', 'U');

insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO)
values (424, 'BLOQUEO ADMINISTRATIVO-LEY 6446', 'U');

commit;
