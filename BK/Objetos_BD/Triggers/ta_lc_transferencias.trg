CREATE OR REPLACE TRIGGER IT.TA_LC_TRANSFERENCIAS
  AFTER DELETE OR UPDATE OR INSERT
     ON LC_TRANSFERENCIAS
    FOR EACH ROW
DECLARE
v_dir_cor_usu_comex varchar2(100):= fug_obt_pardinamico('DIR_MAI_COMEX');
v_dir_correo_ges  ba_usuarios.dir_correo%type;
v_cod_gestor  ba_personas.cod_persona%type;
v_dir_correo_ent ba_usuarios.dir_correo%type := fug_obt_pardinamico('CAM_MAR_DIR_CMX_RTTE');--'comex@bbva.com.py';
v_dir_correo     ba_personas.dir_correo%type;
v_texto          clob;
v_archivo        blob;
v_nom_archivo    varchar2(100);
p_html long;
v_tipo varchar2(10);
v_nro_documento varchar2(30);
v_nro_ord_dna   varchar2(100);
v_dir_mail_todos varchar2(400);
v_horIni         varchar(10);
v_horfin         varchar(10);
v_error          varchar2(4000);
v_can_sof_tok_val NUMBER := 0;
BEGIN
   if updating then
      --sólo transferencias recibidas
      if :new.cod_modalidad = 75 then
        --si cambia de estado actualizar agenda
        if :new.estado <> :old.estado then
           if :new.estado in ('OK','AN','DE') then --si confirma, anula o devuelve
             /*if :new.estado = 'AN' and :old.estado = 'DE' then
                raise_application_error(-20000,'No puede ANULAR la Transferencia DEVUELTA.');
             elsif :new.estado = 'DE' and :old.estado = 'AN' then
                raise_application_error(-20000,'No puede DEVOLVER la Transferencia ANULADA.');
             end if;*/
             if :old.nro_cta_referencia is null then
                --actualizar como realizadas las activiades pendientes referentes a la transferencia
                update cr_agendas b
                   set cod_estado = (Select min(f.cod_estado)
                                       from cr_age_est_actividades f
                                      where f.cod_actividad = b.cod_actividad
                                        and grupo = 'R')--realizada
                 where b.nro_referencia = :new.nro_ref_externa
                   and b.cod_actividad  = 5
                   and exists (Select '1'--- Solo las agendas pendientes ---
                                 from cr_age_est_actividades e
                                where e.cod_actividad = b.cod_actividad
                                  and e.cod_estado = b.cod_estado
                                  and grupo = 'P');
              else --crédito en cuenta
                if :new.estado = 'OK' then   --enviar mail avisando el crédito de la transferencia
                    --- Busco el email del usuario como remitente----
/*                    begin
                       select dir_correo
                         into v_dir_correo_ent
                         from ba_usuarios
                        where cod_usuario = user;
                    exception
                       when others then v_dir_correo_ent := null;
                    end;*/
                    --- Busco el email del cliente
                    begin
                       select dir_correo
                         into v_dir_correo
                         from ba_personas
                        where cod_persona = :new.cod_per_beneficiario;
                    exception
                       when others then v_dir_correo := null;
                    end;
                    --- Enviar mail al cliente
                    if v_dir_correo is not null  and v_dir_correo_ent is not null then
                      it_mail.mail(v_dir_correo_ent,
                             v_dir_correo,
                             'Crédito por Transferencia Recibida',
                             'Sr/a '||:new.nom_beneficiario ||chr(13)||
                             'Le informamos que hemos recibido una Transferencia del exterior bajo ref. '||:new.nro_ref_externa||chr(13)||
                             'por el monto de '||:new.cod_moneda||' '||ltrim(to_char(:new.monto))||'.- La misma ha sido acreditada '||
                             'en su cuenta Nro. '||:new.nro_cta_referencia||','||chr(13)||
                             'previa deduccion de la comision acordada y fue enviada por '||chr(13)||
                             :new.nom_solicitante||' desde '||fue_obt_des_pais(:new.cod_pai_solicitante)||'.'||chr(13)||
                             'Observación: '||:new.observacion||chr(13));

                    end if;
                end if;--ok
             end if;
           end if;
        end if;--cambio estado
        --si modifica los datos del beneficiario
        if :new.cod_per_beneficiario <> :old.cod_per_beneficiario or :new.nom_beneficiario <> :old.nom_beneficiario or
           :new.dir_beneficiario <> :old.dir_beneficiario or :new.tel_beneficiario <> :old.tel_beneficiario then
            --actualizar la agenda si tiene pendiente
            update cr_agendas b
               set cod_persona = nvl(:new.cod_per_beneficiario,fug_obt_per_entidad),
                   det_actividad = 'A nombre de: '||:new.nom_beneficiario || chr(10) ||
                                   'Teléfono:    '||:new.tel_beneficiario || chr(10) ||
                                   'Dirección:   '||:new.dir_beneficiario || chr(10) ||
                                   'Monto:       '||:new.monto||' '||:new.cod_moneda || chr(10) ||
                                   'Enviada por: '||:new.nom_solicitante||' - '||fue_obt_des_ciudad(:new.cod_pai_solicitante,:new.cod_ciu_solicitante) || chr(10) ||
                                   'En fecha:    '||to_char(:new.fec_recepcion,'dd/mm/yyyy')
             where b.nro_referencia = :new.nro_ref_externa
               and b.cod_actividad  = 5
               and exists (Select '1'--- Solo las agendas pendientes ---
                             from cr_age_est_actividades e
                            where e.cod_actividad = b.cod_actividad
                              and e.cod_estado = b.cod_estado
                              and grupo = 'P');

        end if;
      end if;--modalidad
   elsif deleting then
      --sólo transferencias recibidas
      if :old.cod_modalidad = 75 then
        --actualizar las actividades como canceladas si están pendientes
        if :old.nro_cta_referencia is null then
            update cr_agendas b
               set cod_estado = (Select min(f.cod_estado)
                                   from cr_age_est_actividades f
                                  where f.cod_actividad = b.cod_actividad
                                    and grupo = 'C')--cancelada
             where b.nro_referencia = :old.nro_ref_externa
               and b.cod_actividad  = 5
               and exists (Select '1'--- Solo las agendas pendientes ---
                             from cr_age_est_actividades e
                            where e.cod_actividad = b.cod_actividad
                              and e.cod_estado = b.cod_estado
                              and grupo = 'P');
        end if;
     end if;


   elsif inserting then
       --WA: 20/10/2015 Si el usuario es HBANK se envía mail al gestor y a los de comex
     if trim(upper(:NEW.USU_INSERCION))='HBANK' THEN
        v_texto:=null;
        v_archivo:=null;
        v_nom_archivo:=null;
        v_tipo:=null;
        begin
         select UPPER(a.tipo)
           into v_tipo
            from ba_personas a
             where a.cod_persona= :new.cod_per_solicitante;
        exception
          when no_data_found then
              v_tipo:='X';
          when others then
              v_tipo:='X';
        end;
        
        
        if v_tipo='F' then
          -- Consulta si tiene soft-token
          SELECT COUNT(*)
          INTO v_can_sof_tok_val
          FROM bw_otp_seriales bos
          WHERE bos.tipo = 'S'
             AND bos.estado = 'A'
             AND bos.cod_persona = :new.cod_per_solicitante
             AND bos.cod_per_vinculada is null;
          -- Solamente va a buscar si no tiene soft-token
          IF v_can_sof_tok_val = 0 THEN
            --Buscamos si existe en bw_archivos
                begin
                  select UTL_COMPRESS.LZ_UNCOMPRESS(a.contenido), rtrim(ltrim(a.nombre))
                    into v_archivo,v_nom_archivo
                    from bw_archivos a
                     where a.nro_documento= :new.nro_operacion
                      and a.cod_persona= :new.cod_per_solicitante
                      and a.cod_tip_operacion=227; -- TTE/HB
                exception
                 when no_data_found then
                   v_archivo:=null;
                 when others then
                   v_archivo:=null;
                end;
          END IF;
        elsif v_tipo='J' then
               v_nro_documento:=null;
               
                begin
                        select p.nro_documento
                          into v_nro_documento
                          from bw_mov_pendientes p
                          where p.cod_per_principal = :new.cod_per_solicitante
                          and p.cod_tip_mensaje = '227'
                          and p.referencia = :new.nro_referencia
                          and trunc(p.fec_insercion) = TRUNC(sysdate);
                  exception
                  when no_data_found then
                      v_nro_documento:=null;
                  when others then
                      v_nro_documento:=null;
                  end;
                
               
                  if v_nro_documento is not null then
                       --Buscamos si existe en bw_archivos
                        begin
                          select UTL_COMPRESS.LZ_UNCOMPRESS(a.contenido), rtrim(ltrim(a.nombre))
                            into v_archivo,v_nom_archivo
                            from bw_archivos a
                             where a.nro_documento= v_nro_documento
                              and a.cod_persona= :new.cod_per_solicitante
                              and a.cod_tip_operacion=227; -- TTE/HB
                        exception
                         when no_data_found then
                           v_archivo:=null;
                         when others then
                           v_archivo:=null;
                        end;


                  else
                      v_nro_documento:=null;
                  end if;

        else
           v_tipo:=null;
        end if;
        
      if :new.nro_ord_pag_dna is not null then
         v_nro_ord_dna := substr('ORDEN PAGO DNA: '||:new.nro_ord_pag_dna||chr(10), 1, 100);
      end if;

      if v_tipo is not null then

                  --v_texto:= f_blob_to_clob(v_archivo);
                  --Obtenemos el correo del gestor
                  v_cod_gestor:=null;
                  v_dir_correo_ges:=null;
                  v_dir_correo_ent := fug_obt_dir_correo;
                  v_cod_gestor:= FUG_OBT_COD_USU_OFICIAL(:new.cod_per_solicitante);
                  if v_cod_gestor is not null then
                       begin
                          v_dir_correo_ges:= FUG_OBT_DIR_MAIL_USU(v_cod_gestor);
                       exception
                          when others then
                             --Si tuvo problemas que no envíe al gestor, sólo a comex
                             v_dir_correo_ges:=null;
                       end;
                  end if;
           if v_archivo is not null then
                  if v_dir_correo_ges is not null then -- dydmr--11846
                     begin
                       v_horIni := to_char(sysdate,'hh24:mi:ss');
                       p_html := ' Buenas,
                                  <br><br>
                                  Le informamos que se ha ingresado una TTE via HB ingresada por:
                                  <br><br>
                                   CLIENTE: '|| :new.nom_solicitante||
                                   '<br>
                                   MONTO: '||:new.monto ||
                                   '<br>
                                   MONEDA: '|| :new.cod_moneda||
                                   '<br>
                                   FECHA VALOR: '||CASE :new.plazo when 0 then 0 when 1 then 24 else 48 end ||
                                   'HS <br>
                                   BANCO DEL BENEF.: '||:new.cod_banco||'-'||trim(:new.nom_banco) ||
                                   '<br>
                                   SWIFT: '||:new.cod_swi_banco ||
                                    '<br>
                                   BENEFICIARIO: ' ||trim(:new.nom_beneficiario) ||
                                    '<br>
                                   NRO DE CTA/IBAN: ' ||trim(:new.Nro_Cta_Referencia) ||
                                   '<br>
                                   TIPO DE CARGOS: ' ||:new.tip_cargo ||
                                   '<br>
                                   NRO. DE OPERACION: '||:new.nro_operacion ||
                                   '<br>
                                   NRO. DE OPERACION 2: '||:new.Nro_Operacion2;
                        if :new.nro_ord_pag_dna is not null then
                          p_html := p_html  || '<br>
                                               ORDEN PAGO DNA: '||:new.nro_ord_pag_dna;
                        end if;
                          p_html := p_html  || '<br>
                                               USUARIO: '||:new.usu_insercion ||
                                               '<br><br>
                                               Se le envia el presente mail a modo informativo
                                             <br><br>';
                        PRG_ENV_MAIL_ADJUNTO(v_dir_correo_ent,
                                             v_dir_correo_ges,
                                             'Informe de TTE - Via HB - Nro de TTE: '||:NEW.NRO_REFERENCIA,
                                             p_html,
                                             v_archivo,
                                             v_nom_archivo
                                             );
                     exception
                       when others then
                         --Si tiene error el envío , no debe dar error para seguir con operativa
                         -- RAISE_APPLICATION_ERROR(-20001,'Error en envío adj:' || SQLERRM);
                        --null;
                        v_error := sqlerrm;
                        v_horFin := to_char(sysdate,'hh24:mi:ss');
                        insert into ge_log_mail
                                    (fec_envio, cod_persona, dir_correo, mensaje, det_error, nro_cuenta, hor_inicio, hor_fin)
                             values
                                    (sysdate, :new.cod_per_solicitante, substr(NVL(v_dir_correo_ges,'*SIN MAIL*'),1,255),'Informe de TTE - Via HB - Nro de TTE: '||:NEW.NRO_REFERENCIA||chr(10)||p_html,v_error, :NEW.NRO_CTA_DEBITO, v_horIni, v_horFin);
                     end;
                  end if;
                  
                if v_dir_cor_usu_comex is not null then
                 begin
                   v_horIni := to_char(sysdate,'hh24:mi:ss');
                   p_html := ' Buenas,
                              <br><br>
                              Le informamos que se ha ingresado una TTE via HB ingresada por:
                              <br><br>
                               CLIENTE: '|| :new.nom_solicitante||
                               '<br>
                               MONTO: '||:new.monto ||
                               '<br>
                               MONEDA: '|| :new.cod_moneda||
                               '<br>
                               FECHA VALOR: '||CASE :new.plazo when 0 then 0 when 1 then 24 else 48 end ||
                               'HS <br>
                               BANCO DEL BENEF.: '||:new.cod_banco||'-'||trim(:new.nom_banco) ||
                               '<br>
                               SWIFT: '||:new.cod_swi_banco ||
                                '<br>
                               BENEFICIARIO: ' ||trim(:new.nom_beneficiario) ||
                                '<br>
                               NRO DE CTA/IBAN: ' ||trim(:new.Nro_Cta_Referencia) ||
                               '<br>
                               TIPO DE CARGOS: ' ||:new.tip_cargo ||
                               '<br>
                               NRO. DE OPERACION: '||:new.nro_operacion ||
                               '<br>
                               NRO. DE OPERACION 2: '||:new.Nro_Operacion2;
                    if :new.nro_ord_pag_dna is not null then
                      p_html := p_html  || '<br>
                                           ORDEN PAGO DNA: '||:new.nro_ord_pag_dna;
                    end if;
                      p_html := p_html  || '<br>
                                           USUARIO: '||:new.usu_insercion ||
                                           '<br><br>
                                           Se le envia el presente mail a modo informativo
                                         <br><br>';
                    PRG_ENV_MAIL_ADJUNTO(v_dir_correo_ent,
                                         v_dir_cor_usu_comex,
                                         'Informe de TTE - Via HB - Nro de TTE: '||:NEW.NRO_REFERENCIA,
                                         p_html,
                                         v_archivo,
                                         v_nom_archivo
                                         );
                  exception
                    when others then
                       --Si tiene error el envío , no debe dar error para seguir con operativa
                       -- RAISE_APPLICATION_ERROR(-20001,'Error en envío adj:' || SQLERRM);
                      --null;
                        v_error := sqlerrm;
                        v_horFin := to_char(sysdate,'hh24:mi:ss');
                        insert into ge_log_mail
                                    (fec_envio, cod_persona, dir_correo, mensaje, det_error, nro_cuenta, hor_inicio, hor_fin)
                             values
                                    (sysdate, :new.cod_per_solicitante, substr(NVL(v_dir_cor_usu_comex,'*SIN MAIL*'),1,255),'Informe de TTE - Via HB - Nro de TTE: '||:NEW.NRO_REFERENCIA||chr(10)||p_html,v_error, :NEW.NRO_CTA_DEBITO, v_horIni, v_horFin);
                  end;
                end if;
           else
             -- Si es persona juridica o bien si es fisica y no tiene soft-token se continua normal
             IF v_tipo = 'J' OR (v_tipo = 'F' AND v_can_sof_tok_val = 0) THEN
              begin
                v_dir_mail_todos := null;
                if v_dir_correo_ges is not null and v_dir_cor_usu_comex is not null then
                  v_dir_mail_todos :=  v_dir_correo_ges||';'||v_dir_cor_usu_comex;
                elsif v_dir_correo_ges is null and v_dir_cor_usu_comex is not null then
                  v_dir_mail_todos :=  v_dir_cor_usu_comex;
                end if;
                if v_dir_mail_todos is not null then
                  v_horIni := to_char(sysdate,'hh24:mi:ss');
                   it_mail.mail(v_dir_correo_ent,
                                v_dir_mail_todos,
                                'Informe de TTE - Via HB - Nro de TTE: '||:NEW.NRO_REFERENCIA,
                                'Buenas,'|| chr(10)||chr(10)||
                                'Le informamos que se ha ingresado una TTE via HB ingresada por: '|| chr(10)||
                                'CLIENTE: '||:new.nom_solicitante || chr(10)||
                                'MONTO: ' ||:new.monto || chr(10)||
                                'MONEDA: '|| :new.cod_moneda || chr(10)||
                                'FECHA VALOR: '||CASE :new.plazo when 0 then 0 when 1 then 24 else 48 end||' HS'||chr(10)||
                                'BANCO DEL BENEF.: '||:new.cod_banco||'-'||trim(:new.nom_banco)||chr(10)||
                                'SWIFT: '||:new.cod_swi_banco||chr(10)||
                                'BENEFICIARIO: ' ||trim(:new.nom_beneficiario)||chr(10)||
                                'NRO DE CTA/IBAN:' ||trim(:new.Nro_Cta_Referencia)||chr(10)||chr(10)||
                                'TIPO DE CARGOS: ' ||:new.tip_cargo||chr(10)||
                                'NRO. DE OPERACION: '||:new.nro_operacion||chr(10)||
                                'NRO. DE OPERACION 2: '||:new.Nro_Operacion2||chr(10)||
                                v_nro_ord_dna||
                                'USUARIO: '||:new.usu_insercion ||chr(10)|| chr(10)||
                                'Se le envía el presente mail a modo informativo.'
                                );
               end if;
              exception
               when others then
                --Si tiene error el envío , no debe dar error para seguir con operativa
                -- RAISE_APPLICATION_ERROR(-20001,'Error en envío:' || SQLERRM);
                --null;
                v_error := sqlerrm;
                v_horFin := to_char(sysdate,'hh24:mi:ss');
                insert into ge_log_mail
                            (fec_envio, cod_persona, dir_correo, mensaje, det_error, nro_cuenta, hor_inicio, hor_fin)
                     values
                            (sysdate, :new.cod_per_solicitante, substr(NVL(v_dir_mail_todos,'*SIN MAIL*'),1,255),'Informe de TTE - Via HB - Nro de TTE: '||:NEW.NRO_REFERENCIA||chr(10)||
                                'Buenas,'|| chr(10)||chr(10)||
                                'Le informamos que se ha ingresado una TTE via HB ingresada por: '|| chr(10)||
                                'CLIENTE: '||:new.nom_solicitante || chr(10)||
                                'MONTO: ' ||:new.monto || chr(10)||
                                'MONEDA: '|| :new.cod_moneda || chr(10)||
                                'FECHA VALOR: '||CASE :new.plazo when 0 then 0 when 1 then 24 else 48 end||' HS'||chr(10)||
                                'BANCO DEL BENEF.: '||:new.cod_banco||'-'||trim(:new.nom_banco)||chr(10)||
                                'SWIFT: '||:new.cod_swi_banco||chr(10)||
                                'BENEFICIARIO: ' ||trim(:new.nom_beneficiario)||chr(10)||
                                'NRO DE CTA/IBAN:' ||trim(:new.Nro_Cta_Referencia)||chr(10)||chr(10)||
                                'TIPO DE CARGOS: ' ||:new.tip_cargo||chr(10)||
                                'NRO. DE OPERACION: '||:new.nro_operacion||chr(10)||
                                'NRO. DE OPERACION 2: '||:new.Nro_Operacion2||chr(10)||
                                v_nro_ord_dna||
                                'USUARIO: '||:new.usu_insercion ||chr(10)|| chr(10)||
                                'Se le envía el presente mail a modo informativo.',
                                 v_error, :NEW.NRO_CTA_DEBITO, v_horIni, v_horFin);

              end;
             END IF;
           end if;    
      end if;

     end if;

   end if;
END;
/

