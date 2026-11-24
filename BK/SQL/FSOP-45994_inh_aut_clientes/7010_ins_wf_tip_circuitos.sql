begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into wf_tip_circuitos (COD_TIP_CIRCUITO, DESCRIPCION, DETALLE, ESTADO, COD_OBJ_BASE, COD_TAR_INICIAL, REFERENCIA, DET_SQL, COD_PROGRAMA, COD_MODULO, COD_MODALIDAD, NOM_PAR_REFERENCIA, REF_VAL_LIMITE)
values (400, 'VERIF. CHEQUES DEVUELTOS POR INSUF. DE FONDOS', 'Gestion de Cheques devueltos por Insuficiencia de Fondos', 'A', 'WF_CIRCUITOS', null, 'REFERENCIA', 'select ''Cuenta Nro: ''||chr(9)||chr(9)||c.referencia C1,
       ''Cliente : ''||chr(9)||chr(9)||chr(9)||c.cod_persona||'' ''||fue_obt_nom_persona(c.cod_persona) C2,
       ''Tipo : ''||chr(9)||chr(9)||chr(9)||decode(p.tipo, ''F'',''Fisica'', ''Juridica'') C3
       ,''Nro. documento: ''||chr(9)||p.nro_documento C4
  from wf_circuitos c,
       ba_personas p
 where c.cod_persona = p.cod_persona
   and c.cod_tip_circuito = 400  
   and c.referencia = ''&'||'REFERENCIA''
   and c.cod_persona = ''&'||'COD_PERSONA''
    and rownum = 1 ', null, 4, 41, null, null);

insert into wf_tip_circuitos (COD_TIP_CIRCUITO, DESCRIPCION, DETALLE, ESTADO, COD_OBJ_BASE, COD_TAR_INICIAL, REFERENCIA, DET_SQL, COD_PROGRAMA, COD_MODULO, COD_MODALIDAD, NOM_PAR_REFERENCIA, REF_VAL_LIMITE)
values (401, 'VERIF. CHEQUES DEVUELTOS POR CUENTA CANCELADA', 'Gestion de Cheques Devueltos por Cuenta Cancelada', 'A', 'WF_CIRCUITOS', null, 'REFERENCIA', 'select ''Cuenta Nro: ''||chr(9)||chr(9)||c.referencia C1,
       ''Cliente : ''||chr(9)||chr(9)||chr(9)||c.cod_persona||'' ''||fue_obt_nom_persona(c.cod_persona) C2,
       ''Tipo : ''||chr(9)||chr(9)||chr(9)||decode(p.tipo, ''F'',''Fisica'', ''Juridica'') C3
       ,''Nro. documento: ''||chr(9)||p.nro_documento C4
  from wf_circuitos c,
       ba_personas p
 where c.cod_persona = p.cod_persona
   and c.cod_tip_circuito = 401  
   and c.referencia = ''&'||'REFERENCIA''
   and c.cod_persona = ''&'||'COD_PERSONA''
    and rownum = 1 ', null, 4, 41, null, null);

insert into wf_tip_circuitos (COD_TIP_CIRCUITO, DESCRIPCION, DETALLE, ESTADO, COD_OBJ_BASE, COD_TAR_INICIAL, REFERENCIA, DET_SQL, COD_PROGRAMA, COD_MODULO, COD_MODALIDAD, NOM_PAR_REFERENCIA, REF_VAL_LIMITE)
values (402, 'VERIF. CHEQUES DEVUELTOS POR FALLAS FORMALES', 'Gestion de Cheques Devueltos por Fallas Formales', 'A', 'WF_CIRCUITOS', null, 'REFERENCIA', 'select ''Cuenta Nro: ''||chr(9)||chr(9)||c.referencia C1,
       ''Cliente : ''||chr(9)||chr(9)||chr(9)||c.cod_persona||'' ''||fue_obt_nom_persona(c.cod_persona) C2,
       ''Tipo : ''||chr(9)||chr(9)||chr(9)||decode(p.tipo, ''F'',''Fisica'', ''Juridica'') C3
       ,''Nro. documento: ''||chr(9)||p.nro_documento C4
  from wf_circuitos c,
       ba_personas p
 where c.cod_persona = p.cod_persona
   and c.cod_tip_circuito = 402  
   and c.referencia = ''&'||'REFERENCIA''
   and c.cod_persona = ''&'||'COD_PERSONA''
    and rownum = 1 ', null, 4, 41, null, null);
    
commit;    
