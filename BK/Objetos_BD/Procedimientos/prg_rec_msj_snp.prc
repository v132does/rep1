create or replace procedure it.prg_rec_msj_snp is
  v_ref_oid    ge_snp_transferencias.ref_oid%type := null;
  rg_msj_rec   pas_snp.rg_msj := null;
  v_motivo     varchar2(200);
  v_asunto     varchar2(200);
  v_tex_mail   varchar2(200);
  v_hor_ini    varchar2(8);
  v_hor_fin    varchar2(8);
  v_procesado  varchar2(50);
  ex_salir     exception;
  v_dir_correo ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SNP_GRU_DIR_CORREO');
  cursor c_datos is
    select * from ge_snp_transferencias a
     where a.fec_valor = pag_cal.fu_obt_fec_actual(1)
       and a.fec_recepcion is not null
       and a.estado = 'S'
       and a.situacion = 'E'
       and not exists (select 1 from wf_circuitos b
           where b.referencia = a.nro_referencia)
     order by a.fec_insercion;

  function fu_msj_confirmacion(p_cod_swift       in ge_snp_mensajes.cod_msj_swift%type,
                               p_nro_ref_externa in ge_snp_mensajes.nro_ref_externa%type,
                               p_fec_valor       in ge_snp_mensajes.fec_valor%type,
                               p_ref_oid         out ge_snp_transferencias.ref_oid%type)
    RETURN varchar2 IS
    v_ref_oid ge_snp_transferencias.ref_oid%type := null;
    v_pos_ini number := 0;
    v_pos_fin number := 0;
    cursor cu_msj_respuesta is
      select m.cod_msj_swift,
             m.msj_swift,
             pas_snp.fu_pro_val_tag(m.msj_swift, '72', 'N') tag_72
        from ge_snp_mensajes m
       where m.nro_ref_externa = p_nro_ref_externa
         and m.fec_valor = p_fec_valor
       order by m.fec_insercion;
  BEGIN
    p_ref_oid := NULL;
    -- La función busca la primera respuesta válida de confirmación/rechazo para un MT recibido.
    for c in cu_msj_respuesta loop
      -- Campo :72: Referencia OID, sirve para casos de retorno de operaciones
      if c.tag_72 is not null then
        v_pos_ini := instr(c.tag_72, '/OID/');
        v_pos_fin := instr(c.tag_72, pas_snp.fu_obt_salto, v_pos_ini, 1);
        -- Se busca la palabra clave /OID/ dentro del campo 72, recupera el valor hasta el primer salto de línea
        v_ref_oid := substr(c.tag_72, v_pos_ini, v_pos_fin - v_pos_ini);
      end if;
    
      if p_cod_swift = '103' and (c.cod_msj_swift = '910' or
            substr(c.msj_swift, instr(c.msj_swift, '{2:') + 4, 3) = '910') then
        p_ref_oid := v_ref_oid;
        return '910';
      elsif p_cod_swift = '202' and (c.cod_msj_swift in ('900', '910') or
            substr(c.msj_swift, instr(c.msj_swift, '{2:') + 4, 3) in
            ('900', '910')) then
        p_ref_oid := v_ref_oid;
        return nvl(c.cod_msj_swift,substr(c.msj_swift, instr(c.msj_swift, '{2:') + 4, 3));
      end if;
    end loop;
    --
    return null;
    --
  exception
    when others then
      return NULL;
  end fu_msj_confirmacion;
  
  procedure lp_logeo(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2, p_obs varchar2)
  is pragma autonomous_transaction;
  begin
    insert into ge_log_procesos(fecha,cod_programa,cod_proceso,hor_inicio,hor_fin,observacion)
    values(pag_cal.fu_obt_fec_actual(1),'PRG_REC_MSJ_SNP',p_cod_proceso, p_hor_ini, p_hor_fin, p_obs);
    commit;
  exception
    when others then null;
  end;

begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
  delete ge_log_procesos a 
  where a.cod_programa = 'PRG_REC_MSJ_SNP'
    and a.fecha <= last_day(add_months(pag_cal.fu_obt_fec_actual(1),-2));
  for k in c_datos loop
    v_hor_ini := to_char(sysdate,'hh24:mi:ss');
    pas_snp.pr_obt_mensaje(k.nro_referencia, 'N');
    rg_msj_rec := pas_snp.fu_obt_reg_transferencias;
    if fu_msj_confirmacion(k.cod_msj_swift,k.nro_ref_externa,k.fec_valor,v_ref_oid) = '910' then     
      rg_msj_rec.ref_oid := nvl(v_ref_oid, rg_msj_rec.ref_oid);
      prg_cre_savepoint('rechazo');
      pas_snp.pr_pro_msj_rechazado(rg_msj_rec);
      
      if pas_snp.fu_obt_cod_error <> 0 then
        v_procesado := 'ERROR DE RECHAZO - WF GENERADO';
        prg_rol_savepoint('rechazo');
        rg_msj_rec.indemnizado := 'S';
        pas_snp.pr_set_texto( pas_snp.g_msj_error,'Debe registrar una Mensajería de REVERSION MANUAL para enviar a SIPAP.',
                              pas_snp.fu_obt_salto
                            );

        pas_snp.pr_set_transferencias ( rg_msj_rec );
        pas_snp.pr_ini_workflow( rg_msj_rec );
        pas_snp.pr_env_mail( v_dir_correo,
                             'PA MT'||rg_msj_rec.cod_msj_swift||' - Error al Intentar reversar automáticamente la mensajería recibida - SNP',
                             rg_msj_rec,
                             'Se ha Generado un Workfow para la Referencia: '||rg_msj_rec.nro_referencia||'.- '||pas_snp.fu_obt_msj_error
                           );
      else
        v_procesado := 'OK';
        rg_msj_rec.estado := 'R';
        pas_snp.pr_set_transferencias(rg_msj_rec);
        v_motivo   := fue_obt_des_refcodes('TIP_REC_SNP',rg_msj_rec.tip_rechazo);
        v_asunto   := 'PA MT'||rg_msj_rec.cod_msj_swift||' Transacción Reversada Automática - SNP.';
        v_tex_mail := 'Se ha Reversado automáticamente la Operación. ';
        prg_ins_notificacion(trunc(sysdate),
                             fug_obt_dir_correo,
                             v_dir_correo,
                             v_asunto,
                             v_tex_mail ||'A continuación los datos de la mensajería:' ||
                             chr(10) || 'Nro. Operación : ' ||rg_msj_rec.nro_referencia || chr(10) ||
                             'Fecha Valor    : ' ||to_char(rg_msj_rec.fec_valor, 'DD/MM/YYYY') ||
                             chr(10) || 'Monto          : ' ||trim(to_char(rg_msj_rec.monto,'999,999,999,999,999.99')) || chr(10) ||
                             'Usuario        : ' || fue_obt_nom_usuario(user) ||
                             chr(10) || 'Motivo         : ' || '(' ||
                             rg_msj_rec.tip_rechazo || ') ' || v_motivo ||
                             chr(10) || chr(10) ||chr(13) || 'Atentamente.');
      end if;
    else -- No encontró MT de Confirmación
      v_procesado := 'Sin MT de Confirmación';
    end if;
    v_hor_fin := to_char(sysdate,'hh24:mi:ss');
    lp_logeo(k.nro_referencia,v_hor_ini,v_hor_fin,'Resultado del Proceso: '||v_procesado);
  end loop;
exception
  when others then
    prg_rol_savepoint('rechazo');
end;
/

