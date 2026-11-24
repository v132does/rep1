begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into WF_TIP_CIR_TAREAS (COD_TIP_CIRCUITO, COD_TIP_TAREA, DESCRIPCION, DETALLE, ESTADO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_GRU_RESPONSABLE, COD_TIP_TAR_SIGUIENTE, COD_TIP_TAR_RECHAZO, CAN_FIR_REQUERIDAS, AUT_CONJUNTA, TIP_TIEMPO, TIE_ESTIMADO, TIP_ETI_SIGUIENTE, TIP_ETI_RECHAZO, TIP_ETI_CANCELACION, DET_SQL, ACT_AUTOMATICA, ASI_RESPONSABLE, ENV_MAIL, COD_TIP_LIMITE, VE_USUARIO)
values (995, 0, 'CARGA DE SOLICITUD DE ALTA MT ENCAJE ESPECIAL', null, 'A', USER, SYSDATE, USER, SYSDATE, '2', 1, null, null, 'N', 'H', null, 'N', 'N', 'N', null, 'N', null, 'N', null, 'N');
/
insert into wf_tip_cir_tareas (COD_TIP_CIRCUITO, COD_TIP_TAREA, DESCRIPCION, DETALLE, ESTADO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_GRU_RESPONSABLE, COD_TIP_TAR_SIGUIENTE, COD_TIP_TAR_RECHAZO, CAN_FIR_REQUERIDAS, AUT_CONJUNTA, TIP_TIEMPO, TIE_ESTIMADO, TIP_ETI_SIGUIENTE, TIP_ETI_RECHAZO, TIP_ETI_CANCELACION, DET_SQL, ACT_AUTOMATICA, ASI_RESPONSABLE, ENV_MAIL, COD_TIP_LIMITE, VE_USUARIO)
values (995, 1, 'APROBACION DE SOLICITUD DE ALTA MT ENCAJE ESPECIAL', null, 'A', USER, SYSDATE, USER, SYSDATE, '2', null, null, null, 'N', 'H', null, 'N', 'N', 'C', 'DECLARE
  v_msj_swift    ge_snp_mensajes.msj_swift%type;
BEGIN
   
   BEGIN
     SELECT msj_swift
     INTO v_msj_swift
     FROM ge_snp_mensajes m
    WHERE nro_referencia = ''&'||'REFERENCIA''
      AND situacion = ''P'';
   EXCEPTION
     when no_data_found then
       raise_application_error(-20002, ''No se encuentra MT con el Nro. Referencia ''||''&'||'REFERENCIA'');
     when too_many_rows then
       raise_application_error(-20003, ''Existen varios mensajes con el Nro. Referencia ''||''&'||'REFERENCIA''||''. No se puede enviar el mensaje'');
     when others then
       raise;
   END;
   
   IF ''&'||'TIP_ACCION'' = ''A'' THEN
      if nvl(fug_obt_pardinamico(''SNP_HAB_AWS''),''N'') = ''S'' then
              begin
                insert into ge_men_env_sipap(nro_referencia, estado, msj_swift)
                 values(''&'||'REFERENCIA'',''PENDING'',
                         REPLACE(REPLACE(v_msj_swift,
                                         chr(10),
                                         pas_snp.fu_obt_sal_socket),
                                        chr(13),
                                        ''''));
                                        
                   update ge_snp_mensajes
                     set situacion = ''V''
                     WHERE nro_referencia = ''&'||'REFERENCIA'';                   
                                        
              exception 
                when others then 
                   raise_application_error(-20006, ''Al intentar enviar mt999: ''||sqlerrm);                          
              end; 
                                                                                      
       else     
          pas_snp.pr_gen_arc_swi_lote(v_msj_swift);
          
          if pas_snp.fu_obt_cod_error <> 0 then
               raise_application_error(-20006, ''Al intentar enviar al socket: ''||pas_snp.fu_obt_msj_error);
          else
             update ge_snp_mensajes
                     set situacion = ''V''
                     WHERE nro_referencia = ''&'||'REFERENCIA''; 
           end if;

       end if;
   ELSIF ''&'||'TIP_ACCION'' = ''C'' THEN
      update ge_snp_mensajes
         set situacion = ''C''
         WHERE nro_referencia = ''&'||'REFERENCIA'';
   END IF;
EXCEPTION
  when others then
    if sqlcode <= -20000 then
       raise;
    else
      raise_application_error(-20007, ''Al intentar ejecutar la tarea: ''||sqlerrm);
    end if;
   END;', 'N', null, 'N', null, 'N');
   
commit;
