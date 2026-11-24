begin
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
end;
/
insert into wf_tip_cir_tareas
  (cod_tip_circuito,
   cod_tip_tarea,
   descripcion,
   detalle,
   estado,
   cod_gru_responsable,
   cod_tip_tar_siguiente,
   cod_tip_tar_rechazo,
   can_fir_requeridas,
   aut_conjunta,
   tip_tiempo,
   tie_estimado,
   tip_eti_siguiente,
   tip_eti_rechazo,
   tip_eti_cancelacion,
   det_sql,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion,
   ve_usuario,
   cod_tip_limite,
   act_automatica,
   asi_responsable,
   env_mail)
values
  (925,
   1,
   'INSTRUCCIÓN A LA ESCRIBANÍA.',
   'Instrucción a la Escribanía',
   'S',
   '50',
   null,
   0,
   1,
   'N',
   'D',
   9999,
   'A',
   'R',
   'N',
   null,
   user,
  sysdate,
   user,
   sysdate,
   'N',
   null,
   'N',
   null,
   'N');
commit;
insert into wf_tip_cir_tareas
  (cod_tip_circuito,
   cod_tip_tarea,
   descripcion,
   detalle,
   estado,
   cod_gru_responsable,
   cod_tip_tar_siguiente,
   cod_tip_tar_rechazo,
   can_fir_requeridas,
   aut_conjunta,
   tip_tiempo,
   tie_estimado,
   tip_eti_siguiente,
   tip_eti_rechazo,
   tip_eti_cancelacion,
   det_sql,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion,
   ve_usuario,
   cod_tip_limite,
   act_automatica,
   asi_responsable,
   env_mail)
values
  (925,
   2,
   'VERIFICACIÓN DEL BORRADOR.',
   'Verificación del borrador.',
   'S',
   '50',
   null,
   null,
   1,
   'N',
   'D',
   9999,
   'A',
   'R',
   'N',
   'declare
  v_wf_error varchar2(2000);
  v_nro_cuenta ge_cuentas.nro_cuenta%type;
  v_cod_persona varchar2(15);
begin
     
  if ''&' || 'TIP_ACCION'' = ''A'' then
    select cod_persona
        into v_cod_persona
       from wf_circuitos
     where COD_CIRCUITO = ''&' || 'COD_CIRCUITO'';
     
    it.prp_env_datos(v_cod_persona,''N'');
    
  end if;
end;',
   user,
   sysdate,
   user,
   sysdate,
   'N',
   null,
   'N',
   null,
   'N');
commit;

insert into wf_tip_cir_tareas
  (cod_tip_circuito,
   cod_tip_tarea,
   descripcion,
   detalle,
   estado,
   cod_gru_responsable,
   cod_tip_tar_siguiente,
   cod_tip_tar_rechazo,
   can_fir_requeridas,
   aut_conjunta,
   tip_tiempo,
   tie_estimado,
   tip_eti_siguiente,
   tip_eti_rechazo,
   tip_eti_cancelacion,
   det_sql,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion,
   ve_usuario,
   cod_tip_limite,
   act_automatica,
   asi_responsable,
   env_mail)
values
  (925,
   3,
   'GESTIÓN DE FIRMA DE ESCRITURA.',
   'Gestión de firma de Escritura.',
   'S',
   '50',
   null,
   null,
   1,
   'N',
   'D',
   9999,
   'A',
   'R',
   'N',
   'declare
  v_wf_error varchar2(2000);
  v_nro_cuenta ge_cuentas.nro_cuenta%type;
  v_cod_persona varchar2(15);
begin
  if (''&' || 'TIP_ACCION'' = ''A'' or ''&' ||
    'TIP_ACCION'' = ''R'') then
    select cod_persona
        into v_cod_persona
       from wf_circuitos
     where COD_CIRCUITO = ''&' || 'COD_CIRCUITO'';
     
    it.prp_env_datos(v_cod_persona,''U'');
 
  end if;
end;',
   user,
   sysdate,
   user,
   sysdate,
   'N',
   null,
   'N',
   null,
   'N');
commit;

insert into wf_tip_cir_tareas
  (cod_tip_circuito,
   cod_tip_tarea,
   descripcion,
   detalle,
   estado,
   cod_gru_responsable,
   cod_tip_tar_siguiente,
   cod_tip_tar_rechazo,
   can_fir_requeridas,
   aut_conjunta,
   tip_tiempo,
   tie_estimado,
   tip_eti_siguiente,
   tip_eti_rechazo,
   tip_eti_cancelacion,
   det_sql,
   usu_insercion,
   fec_insercion,
   usu_modificacion,
   fec_modificacion,
   ve_usuario,
   cod_tip_limite,
   act_automatica,
   asi_responsable,
   env_mail)
values
  (925,
   4,
   'FIRMA DE ESCRITURA FINALIZADA',
   'Firma de Escritura finalizada.',
   'S',
   '50',
   null,
   null,
   1,
   'N',
   'D',
   9999,
   'A',
   'R',
   'N',
   null,
   user,
   sysdate,
   user,
   sysdate,
   'N',
   null,
   'N',
   null,
   'N');

commit;
