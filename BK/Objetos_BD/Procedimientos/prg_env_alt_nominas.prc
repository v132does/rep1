CREATE OR REPLACE PROCEDURE IT.PRG_ENV_ALT_NOMINAS (p_cod_ente IN ge_entes.cod_ente%TYPE,
                                                p_nro_lote IN ge_pag_sue_emp.nro_lote%type) IS

  v_nom_ente        ba_personas.nom_completo%type; --ge_entes.descripcion%type;  -- 01/2017 --
  v_dir_mail_cre    ge_alt_empleados.not_mail%type;
  v_cod_per_ente    ge_entes.cod_persona%type;
  v_dir_mail_nom    ge_par_dinamicos.val_parametro%type;

  v_texto           varchar2(2000);
  v_texto_detalle   clob;
  v_texto_detalle2  clob;
  v_adjunto         clob;
  v_adjunto_error   clob;
  v_cabecera        clob;
  v_cabecera_error  clob;
  v_nom_adj         varchar2(500);

  -- Variables para mail
  v_conn     utl_smtp.connection;
  v_asunto   VARCHAR2(2000);
  v_mje_mail LONG;
  --
  v_hini_mail  ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail  ge_ra_log_mail.hor_fin%type;
  v_det_error  ge_ra_log_mail.det_error%type;
  --
  v_can_normal number(10):=0;
  v_can_error  number(10):=0;
  v_pie_normal varchar2(30000);
  v_pie_error  varchar2(30000);
  c_dir_mail   ba_personas.dir_correo%type := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--fug_obt_dir_correo;
  v_reasignada varchar2(100); -- DYDMR-5823 -- 01/2017 --
  v_error      varchar2(2000); -- DYDMR-6122 -- 02/2017 --

  --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  v_membrete LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P',c_dir_mail);
  --
  CURSOR g_ente is
    select e.cod_ente, e.nro_lote, e.cantidad,
           e.estado, e.fec_cierre, e.not_mail, e.fec_recepcion
     from ge_alt_empleados e
    where e.cod_ente = p_cod_ente
      and e.nro_lote = p_nro_lote;

  -- DYDMR-5823 -- 01/2017 -- Se modifica el cursor --
  CURSOR c_rec(v_ente ge_pag_sue_emp.cod_empresa%TYPE,
               v_lote ge_pag_sue_emp.nro_lote%TYPE) is
    select distinct g.nro_operacion, g.nro_cuenta,     			-- DYDMR-6122 -- 02/2017 -- Se trae valores distintos porque los registros son duplicados en la tabla ge_pag_sue_emp.
           g.pri_nombre, g.seg_nombre, g.pri_apellido, g.seg_apellido,
           g.nro_cedula, g.tip_documento, g.cod_empresa, g.doc_pais, -- g.estado, 
           g.nro_lote, trunc(e.fec_recepcion) fec_recepcion, trunc(e.fec_cierre) fec_cierre,
           nvl(cc.cod_moneda,ah.cod_moneda) cod_moneda --, g.error               
      from ge_pag_sue_emp g, ge_alt_empleados e,
           cc_cta_corrientes cc, ah_cta_vistas ah
     where e.cod_ente = g.cod_empresa
       and e.nro_lote = g.nro_lote
       and g.nro_cuenta = cc.nro_cuenta(+)
       and g.nro_cuenta = ah.nro_cuenta(+)
       and g.cod_empresa = v_ente
       and g.nro_lote = v_lote
       and g.estado in ('N','R')
       and g.fec_insercion = ( select min(fec_insercion) f
                                 from ge_pag_sue_emp p
                                where p.cod_empresa = g.cod_empresa
                                  and p.nro_lote = g.nro_lote
                                  and p.nro_cedula = g.nro_cedula
                                  and p.tip_documento = g.tip_documento
                                  and p.pri_nombre = g.pri_nombre
                               )
    order by 1 asc;          
  
  -- DYDMR-5823 -- 01/2017 -- Funcion para verificar CUENTA REASIGNADA --
  FUNCTION lf_ver_cta_reasignada( v_cod_ente   ge_pag_sue_emp.cod_empresa%type,
                                  v_nro_lote   ge_pag_sue_emp.nro_lote%type,
                                  v_nro_cedula ge_pag_sue_emp.nro_cedula%type
                                   ) return varchar2 is
    v_result varchar2(100);
  BEGIN
    select distinct 'CUENTA REASIGNADA' 
      into v_result
      from ge_pag_sue_emp a
     where a.cod_empresa = v_cod_ente
       and a.nro_lote = v_nro_lote
       and a.nro_cedula = v_nro_cedula
       and ( a.error like '%Cliente%ya%posee%CTA%asignada%Empresa%'  -- DYDMR-6437 --
             or a.error like '%Cliente%ya%posee%CTA%para%Ente%'
             or a.error like '%Cliente%ya%posee%CTA%para%Sub%Modalidad%'
            );
     return v_result;
  EXCEPTION
    when others then
      return NULL;
  END;
  --
  -- DYDMR-6122 -- 02/2017 -- Se agrega la funcion para concatenar la descripcion de errores registrados
  FUNCTION lf_obt_errores( v_cod_ente   ge_pag_sue_emp.cod_empresa%type,
                          v_nro_lote   ge_pag_sue_emp.nro_lote%type,
                          v_nro_cedula ge_pag_sue_emp.nro_cedula%type
                         ) return varchar2 is
 CURSOR c_err is
  select a.error
    from ge_pag_sue_emp a
   where a.cod_empresa = v_cod_ente
     and a.nro_lote = v_nro_lote
     and a.nro_cedula = v_nro_cedula; 
   v_result varchar2(2000);                      
 BEGIN
   for r in c_err loop
     if v_result is null then
       v_result := r.error;
     else
       if length(v_result||' '||r.error) <= 2000 then
         v_result := v_result||' '||r.error;
       else
         return v_result;
       end if;
     end if;
   end loop;
   return v_result;
 EXCEPTION
   when others then
      return NULL;
 END;
 --
begin

  begin
    for j in g_ente loop
      v_cod_per_ente := fue_obt_per_ente(j.cod_ente);
      v_nom_ente := fue_obt_nom_persona(v_cod_per_ente);
      --Se agrega membrete de BBVA
       v_texto := '<br><br>
                   <br><br>
                     Estimado Cliente ' ||v_nom_ente|| ':
                   <br><br>
                     Le informamos que se realizó el proceso de altas de clientes nómina vía web correspondiente a la fecha ' ||
                     to_char(j.fec_recepcion, 'DD/MM/YYYY') || ', y dados de alta en
                   <br>
                     fecha ' ||to_char(j.fec_cierre, 'DD/MM/YYYY')||'. El mismo se detallada en el archivo adjunto.
                   <br><br>
                     Los kits Nominas serán direccionados a la Sucursal solicitada en un plazo no mayor a 72 hs habiles, excepto aquellas cuentas reasignadas.
                   <br><br>
                     Los empleados que poseen cuentas reasignadas, y precisen una nueva Tarjeta de Debito deberán acercarse a la Sucursal más cercana
                   <br>
                     y solicitar la reimpresion.
                   <br><br>
                     Atentamente.
                   <br><br>
                   <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                   <br><br>
                   <br><br>';

      v_cabecera := 'Nro. Cuenta' || chr(9) || 'Moneda' || chr(9) || 'Titular' || chr(9) || 'Doc. Identidad' || chr(9) ||
                    'Cod. Ente' || chr(9) || 'Fec. Solicitud' || chr(9) || 'Fec. Alta' || chr(9) || 'Reasignada';

      v_cabecera_error := 'Tipo Doc.' || chr(9) || 'Nro. Doc' || chr(9) ||
                          'Primer Apellido' || chr(9) || 'Segundo Apellido' || chr(9) || 'Nombres' || chr(9) ||
                          'Fec. Solicitud' || chr(9) || 'Fec. Alta';

      v_texto_detalle   := null;
      v_texto_detalle2  := null;

      v_adjunto         := null;
      v_adjunto_error   := null;
      v_det_error       := null;
      v_hini_mail       := to_char(sysdate,'hh24:mi:ss');
      v_can_normal      :=0;
      v_can_error       :=0;
      BEGIN
        for k in c_rec(j.cod_ente,j.nro_lote) loop

          v_cod_per_ente := fue_obt_per_ente(k.cod_empresa);
          v_nom_ente     := fue_obt_nom_persona(v_cod_per_ente);
          v_dir_mail_cre := j.not_mail;
          v_dir_mail_nom := fug_obt_pardinamico('MAIL_NOM_NOT_ENTE');
           
          v_reasignada := lf_ver_cta_reasignada(k.cod_empresa,k.nro_lote,k.nro_cedula); -- DYDMR-5823 -- 01/2017 --
          v_error      := lf_obt_errores(k.cod_empresa,k.nro_lote,k.nro_cedula); -- DYDMR-6122 -- 02/2017 --
           
           if k.nro_cuenta is not null and (k.nro_operacion is not null
               or v_error like '%Cliente%ya%posee%CTA%asignada%Empresa%' -- DYDMR-6437 --
               or v_error like '%Cliente%ya%posee%CTA%para%Ente%'
               or v_error like '%Cliente%ya%posee%CTA%para%Sub%Modalidad%'
               or v_error like '%persona%mismo%Doc%Pri%Nom%Pri%Ape%' )   -- DYDMR-6122 -- 02/2017 --
               and nvl(v_error,'x') not like '%Cliente inhibido para CTA CTE. Se ha creado una CTA. AV.%'  then
            v_adjunto := v_adjunto || '''' || k.nro_cuenta || chr(9) || k.cod_moneda || chr(9) ||
                         k.pri_nombre ||' '|| k.seg_nombre ||' '|| k.pri_apellido ||' '||
                         k.seg_apellido || chr(9) || '''' || k.nro_cedula || chr(9) || k.cod_empresa || chr(9) ||
                         k.fec_recepcion || chr(9) || k.fec_cierre || chr(9) || v_reasignada || chr(10);
          elsif (k.nro_cuenta is null or v_error like '%Cliente inhabilitado para operar con CTA. AV. y CTA. CTE.%'
            or v_error like '%Cliente inhibido para CTA CTE. Se ha creado una CTA. AV.%'
            or v_error like '%Cliente inhibido para operar con CTA. AV. y CTA. CTE.%'
            or v_error like '%Cliente inhibido para operar con CTA. CTE. y CTA. AV.%') then
            v_adjunto_error := v_adjunto_error || k.tip_documento || chr(9) ||
                               '''' || k.nro_cedula || chr(9) || k.pri_apellido || chr(9) || k.seg_apellido || chr(9) ||
                               k.pri_nombre ||' '|| k.seg_nombre || chr(9) ||
                               k.fec_recepcion || chr(9) || k.fec_cierre || chr(10);


          end if;
        end loop;
        --Verificamos si se insertaron registros normales en la tabla para enviar.
        begin
          select count(*)
            into v_can_normal
            from ge_pag_sue_emp a
           where a.cod_empresa=j.cod_ente
             and a.nro_lote=j.nro_lote
             and a.nro_cuenta is not null
             and nvl(a.error,'x') not like '%Cliente inhibido para CTA CTE. Se ha creado una CTA. AV.%'
             and nvl(a.error,'x') not like '%persona%mismo%Doc%Pri%Nom%Pri%Ape%'  -- DYDMR-6122 -- 02/2017 --
             and (a.nro_operacion is not null
               or v_error like '%Cliente%ya%posee%CTA%asignada%Empresa%'
               or v_error like '%Cliente%ya%posee%CTA%para%Ente%' 
               or v_error like '%Cliente%ya%posee%CTA%para%Sub%Modalidad%')
             and a.fec_insercion = ( select min(fec_insercion)                 -- DYDMR-5823 -- 01/2017 --
                                       from ge_pag_sue_emp p
                                      where p.cod_empresa = a.cod_empresa
                                        and p.nro_lote = a.nro_lote
                                        and p.nro_cedula = a.nro_cedula
                                        and p.tip_documento = a.tip_documento
                                        and p.pri_nombre = a.pri_nombre );
        exception
          when no_data_found then
            v_can_normal:=0;
          when others then
             v_can_normal:=0;
        end;
        --Verificamos si se insertaron registros con errores en la tabla para enviar.
        begin
          select count(*)
            into v_can_error
            from ge_pag_sue_emp a
           where a.cod_empresa=j.cod_ente
             and a.nro_lote=j.nro_lote
             and (a.nro_cuenta is null or  a.error like'%Cliente inhabilitado para operar con CTA. AV. y CTA. CTE.%'
                    or a.error like '%Cliente inhibido para CTA CTE. Se ha creado una CTA. AV.%'
                    or a.error like '%Cliente inhibido para operar con CTA. AV. y CTA. CTE.%'
                    or a.error like '%Cliente inhibido para operar con CTA. CTE. y CTA. AV.%') ;
        exception
          when no_data_found then
            v_can_error:=0;
          when others then
             v_can_error:=0;
        end;

        if nvl(v_can_normal,0)> 0 then
           v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                              v_cabecera || chr(10) || v_adjunto || chr(10);
           v_pie_normal:= chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||v_can_normal||chr(10);
        end if;

        if nvl(v_can_error,0)> 0 then
           v_texto_detalle2 :='Operaciones no Procesadas' ||chr(10)||
                              v_cabecera_error || chr(10) || v_adjunto_error|| chr(10);
           v_pie_error:= chr(9)||chr(9)||chr(9)||chr(9)||'Total No Procesados :'||chr(9)||v_can_error||chr(10);
        end if;
      EXCEPTION
        when others then
           v_det_error := substr(sqlerrm,1,4000);
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, 'altas_clientes_nomina','ERROR', 'Altas.Clientes.Nomina', v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
      END;

     if v_dir_mail_cre is not null and nvl(fug_ind_produccion,'N') = 'S' then       

        v_nom_adj := 'ALT_CLIE_NOMINA';

        v_asunto   := 'Alta Clientes Nómina';
        v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                      chr(10) || chr(10) || chr(10) || V_FIN|| chr(10) || V_PIE;

        v_det_error    := null;

        BEGIN

            if nvl(v_can_normal,0)>0 then
               --******************PARA NORMAL *************************************
                v_conn  := it_mail.begin_mail(c_dir_mail,
                                              v_dir_mail_cre||';'||v_dir_mail_nom,
                                              v_asunto,
                                              IT_MAIL.MULTIPART_MIME_TYPE);

                it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

                it_mail.begin_attachment(v_conn,
                                         'text/plain',
                                         false,
                                         v_nom_adj || '.xls');

                v_texto_detalle := chr(10) || v_nom_ente || CHR(9) ||
                                   'ALTA DE CLIENTES NOMINA' || CHR(10)||
                                   v_texto_detalle;

                it_mail.write_text(v_conn, v_texto_detalle);

                it_mail.write_text(v_conn, v_pie_normal);

            end if;
            if nvl(v_can_error,0)>0 then
                --*****************Para Errores************************************************
               if v_can_normal = 0 then
                  v_conn  := it_mail.begin_mail(c_dir_mail,
                                                v_dir_mail_cre||';'||v_dir_mail_nom,
                                                v_asunto,
                                                IT_MAIL.MULTIPART_MIME_TYPE);

                  it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

                  it_mail.begin_attachment(v_conn,
                                           'text/plain',
                                            false,
                                            v_nom_adj || '.xls');
                end if;

                v_texto_detalle2 := chr(10) || CHR(9) || CHR(9) ||
                                    'ALTA DE CLIENTES NOMINA' || CHR(10)||
                                    v_texto_detalle2;

                it_mail.write_text(v_conn, v_texto_detalle2);

                it_mail.write_text(v_conn, v_pie_error);

           end if;

           it_mail.end_mail(v_conn);
       EXCEPTION
        when utl_smtp.transient_error or utl_smtp.permanent_error then
            begin
              utl_smtp.quit(v_conn);
            exception
            when utl_smtp.transient_error or utl_smtp.permanent_error then
              null;
            end;
            v_det_error := substr(sqlerrm,1,4000);
       END;

        v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
        -- Insertamos en la tabla de log si ocurrio algun error al enviar el mail
        IF v_det_error is not null THEN
            INSERT INTO ge_ra_log_mail
             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_nom_adj, c_dir_mail, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
            COMMIT;
            v_det_error    := null;
        END IF;
      end if;

    end loop;

  EXCEPTION
    when others then
      --null;
      -- DYDMR-6122 -- 02/2017 --
      v_det_error := nvl(v_det_error,sqlerrm);
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_nom_adj, c_dir_mail, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;
  END;  
end;
/

