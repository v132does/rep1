DECLARE
v_cod_ente ge_entes.cod_ente%type;
BEGIN
PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1;

 Select max(cod_ente) + 1
  into v_cod_ente--into :ge_entes.cod_ente
  from ge_entes;

DBMS_OUTPUT.put_line('COD_ENTE NUEVO: '||v_cod_ente);

--CABECERA
insert into ge_entes (COD_ENTE, DESCRIPCION, COD_PERSONA, TIPO)
values (v_cod_ente, 'ADUANAS PAGO DE SERVICIOS', '1', 'CN');

--DETALLE
insert into ge_par_entes (COD_ENTE, PARAMETRO, VAL_PARAMETRO)
values (v_cod_ente, 'COD_TRA_PAD_PAG_SERVICIO', '8593');

insert into ge_par_entes (COD_ENTE, PARAMETRO, VAL_PARAMETRO)
values (v_cod_ente, 'COD_TRA_DEB_PAG_SERVICIO', '8527');

insert into ge_par_entes (COD_ENTE, PARAMETRO, VAL_PARAMETRO)
values (v_cod_ente, 'COD_TRA_CRE_PAG_SERVICIO', '8085');

insert into ge_par_entes (COD_ENTE, PARAMETRO, VAL_PARAMETRO)
values (v_cod_ente, 'CTA_OP_PAG_SERVICIO2', '900031400');

insert into ge_par_entes (COD_ENTE, PARAMETRO, VAL_PARAMETRO)
values (v_cod_ente, 'CTA_OP_PAG_SERVICIO', '900027640');

--REFERENCIA
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('COD_ENT_PAG_SERVICIO', 'Codigo de Ente para Pago de Servicios', '10000', v_cod_ente, 'Ente Pago Servicios', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('COD_ENT_PAG_SERVICIO', 'Codigo de Ente para Pago de Servicios', '10000,10004', v_cod_ente, 'Ente Pago Servicios', 'S');

COMMIT;  
END;
