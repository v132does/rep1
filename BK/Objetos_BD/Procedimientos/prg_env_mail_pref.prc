CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAIL_PREF (p_frecuencia in varchar) is
 -- Envia reportes automaticos por mail en formato excel
  v_nombre           varchar2(100);
  v_asunto           varchar2(100);
  v_contenido        varchar2(400);
  v_dir_correo_de    varchar2(100) := fug_obt_pardinamico('CAM_MAR_DIR_PREM_RTTE'); --'premium@bbva.com';
  v_dir_correo_para    varchar2(1000);--se aumenta de 300 a 1000 , en ge_par_dinamicos esta definido mas de 1 correo por lo que ya supera los 300 caracteres DYDMR-15561

  v_fec_actual            date;
  v_fec_cal                 varchar2(2);
  conn               utl_smtp.connection;
  v_det_error varchar2(100);

  -- Variables de archivo adjunto
  v_cabecera varchar(1000);-- raw(32767);
  v_detalle varchar(1000);--raw(32767);


  CURSOR c_personas IS
     select a.nom_completo Nom_completo,
            pf.cod_sexo sexo,
            fue_obt_nom_usuario(fug_obt_cod_usu_oficial(a.cod_persona)) gestor,
            fue_obt_nom_ente(FUE_OBT_COD_ENT_PER(a.cod_persona)) ente_asocionado,
            (select round(sum((t.sal_contable * nvl(pag_gen.fu_obt_cotizacion(t.cod_moneda,
                                                                              sysdate),
                                                    1))),
                          2) saldo_contable
               from ge_cuentas t, ge_cta_clientes v
              where t.nro_cuenta = v.nro_cuenta
                and v.cod_persona = a.cod_persona
                and v.relacion = 'P'
                and t.cod_modulo in (3, 4)) prom_pasivo,
            pf.fec_nacimiento,
            nvl(dir.dire, direc.direccion) direccion,
            to_char(tel.area) || '-' || to_char(tel.telefono) tel_principal,
            max(to_char(tela.area) || '-' || to_char(tela.telefono)) tel_celular,
            decode(cli.cod_seg_preferente, 1, 'VIP', 2, 'PREMIUM', 'OTRO') Preferente,
            a.cod_persona
       from ba_personas a,
            ba_per_fisicas pf,
            ge_clientes cli,
            ge_cta_clientes cta,
            ba_direcciones direc,
            (select ax.cod_persona, ax.direccion || ' ' || ax.det_direccion dire
               from ge_ext_clientes ax
              where ax.fec_extracto =
                    (select max(xx.fec_extracto) from ge_ext_clientes xx)
                and ax.cod_extracto = 1) dir,
            ba_telefonos tel,
            (select telc.cod_persona, telc.telefono, telc.area
               from ba_telefonos telc
              where telc.tipo = 'P'
                and telc.tip_linea = 'C') tela
      where a.cod_persona = cli.cod_persona
        and a.cod_persona = pf.cod_persona
        and cli.cod_persona = pf.cod_persona
        and cta.cod_persona = cli.cod_persona
        and cli.cli_especial = 'S'
        and dir.cod_persona(+) = a.cod_persona
        and tela.cod_persona(+) = a.cod_persona
        and a.cod_persona = direc.cod_persona
        and direc.principal = 'S'
        and cli.cod_seg_preferente in (2)
        and tel.cod_persona = a.cod_persona
        and tel.principal = 'S'
        and exists
      (select 1
               from ge_paq_clientes pq
              where pq.estado = 'N'
                and pq.cod_persona = a.cod_persona
                and exists
              (select 1
                       from ge_par_dinamicos pd
                      where pd.parametro = 'COD_PAQ_PREMIUM'
                        and instr(pd.val_parametro, ',' || pq.cod_paquete || ',') > 0))
      group by a.nom_completo,
               pf.cod_sexo,
               a.cod_persona,
               pf.fec_nacimiento,
               nvl(dir.dire, direc.direccion),
               to_char(tel.area) || '-' || to_char(tel.telefono),
               cli.cod_seg_preferente
      order by cli.cod_seg_preferente, pf.fec_nacimiento desc;
begin

    v_fec_actual := trunc(sysdate);
    v_asunto       := null;


  -- Empezamos a cargar los datos del mail a enviar

    if p_frecuencia = 'M' then
          v_nombre := 'Cumpleanhos PREMIUM.xls';
          v_asunto := 'Listado de cumpleanhos - Clientes PREMIUM';
          v_contenido := 'Adjunto archivo conteniendo los datos del Listado de cumpleanhos de clientes PREMIUM '||v_fec_actual||'.';
          
     --Se concatena de esta forma los mails ya que pueden cargarse en blanco y genera inconvenientes al momento del envío. LA-06-2015
          --1
          IF instr(fug_obt_pardinamico('EMAIL_PREF_MKT'),'@') > 0 THEN
             v_dir_correo_para := fug_obt_pardinamico('EMAIL_PREF_MKT')||';';
          END IF;
          --2
          IF instr(fug_obt_pardinamico('EMAIL_PREF_MKT2'),'@') > 0 THEN
             v_dir_correo_para := v_dir_correo_para||fug_obt_pardinamico('EMAIL_PREF_MKT2')||';';
          END IF;
          --3
          IF instr(fug_obt_pardinamico('EMAIL_PREF_MKT3'),'@') > 0 THEN
             v_dir_correo_para := v_dir_correo_para||fug_obt_pardinamico('EMAIL_PREF_MKT3')||';';
          END IF;
          --4
          IF instr(fug_obt_pardinamico('EMAIL_PREF_COM'),'@') > 0 THEN
             v_dir_correo_para := v_dir_correo_para||fug_obt_pardinamico('EMAIL_PREF_COM');
          END IF;
          
         /* v_dir_correo_para := fug_obt_pardinamico('EMAIL_PREF_MKT')||';'||
                                       fug_obt_pardinamico('EMAIL_PREF_MKT2')||';'||
                                       fug_obt_pardinamico('EMAIL_PREF_MKT3')||';'||
                                       fug_obt_pardinamico('EMAIL_PREF_COM');*/
      else
          v_nombre := 'Cumpleanhos PREMIUM de HOY.xls';
          v_asunto := 'Cumpleanhos HOY - Clientes PREMIUM';
          v_contenido := 'Adjunto archivo conteniendo los datos de cumpleanhos de clientes PREMIUM de HOY '||v_fec_actual||'.';
          v_dir_correo_para := '';
     end if;

 begin

         conn := it_mail.begin_mail(v_dir_correo_de, v_dir_correo_para, v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(conn,v_contenido,'text/plain');
         it_mail.begin_attachment(conn,'application/vnd.ms-excel',false,v_nombre);
    -- Titulo del reporte
    -- Colocar el titulo a los campos
         v_cabecera := 'NOMBRE'||chr(9)||'SEXO'||chr(9)||'GESTOR'||chr(9)||'ENTE ASOCIADO'||chr(9)||'PROM PASIVO'||chr(9)||'FECHA DE NACIMIENTO'||chr(9)||'DIRECCION'||chr(9)||'LINEA BAJA'||chr(9)||'CELULAR'||chr(13)||chr(10);
      --** Arma el Archivo Anexo.
        it_mail.write_text(conn,v_cabecera);
      --**
        v_detalle := '';

       begin
            select to_char(add_months(a.fec_actual,1),'MM')
            into v_fec_cal
            from ge_calendarios a
            where a.cod_modulo = 1;
            exception
            when others then
            v_fec_cal := to_char(add_months(sysdate,1),'MM');
        end;

      -- detalle del reporte
    FOR REC IN c_personas LOOP
           if p_frecuencia = 'M' then
                  if to_char(rec.fec_nacimiento,'MM') = v_fec_cal then

                     --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
                              v_detalle := rec.nom_completo||chr(9)||rec.sexo||chr(9)||rec.gestor||chr(9)||rec.ente_asocionado||chr(9)||rec.prom_pasivo||chr(9)||rec.fec_nacimiento||chr(9)||rec.direccion||chr(9)||rec.tel_principal||chr(9)||rec.tel_celular||chr(13)||chr(10);
                      --Escribir la linea en el archivo
                      --**
                             it_mail.write_text(conn,v_detalle);
                             v_detalle := '';
                    --**
                    end if;
           end if;

      EXIT WHEN c_personas%NOTFOUND or p_frecuencia <> 'M';
    END LOOP;

    FOR REC2 IN c_personas LOOP
             if p_frecuencia = 'D' then
                  if to_char(to_date(rec2.fec_nacimiento),'DD/MM') = to_char(to_date(sysdate),'DD/MM') then
                    --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
                    v_detalle := rec2.nom_completo||chr(9)||rec2.sexo||chr(9)||rec2.gestor||chr(9)||rec2.ente_asocionado||chr(9)||rec2.prom_pasivo||chr(9)||rec2.fec_nacimiento||chr(9)||rec2.direccion||chr(9)||rec2.tel_principal||chr(9)||rec2.tel_celular||chr(13)||chr(10);
                   --Escribir la linea en el archivo
                    --**
                    it_mail.write_text(conn,v_detalle);
                    v_detalle := '';
                    --**
                 end if;
            end if;

      EXIT WHEN c_personas%NOTFOUND or p_frecuencia <> 'D';
    END LOOP;
     --**
        it_mail.end_mail(conn);
    --**
  exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
    begin
      utl_smtp.quit(conn);
    exception
    when utl_smtp.transient_error or utl_smtp.permanent_error then
      null;
    end;
    v_det_error := substr(sqlerrm,1,4000);
  end;

--
  commit;
--

exception
  when others then
    raise_application_error(-20000,'Error al Generar listado. '||sqlerrm);
end;
/

