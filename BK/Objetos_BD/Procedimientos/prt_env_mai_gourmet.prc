CREATE OR REPLACE PROCEDURE IT.prt_env_mai_gourmet IS

  v_fec_actual  date default pag_cal.fu_obt_fec_actual(1); 
  v_cod_per_debito  ge_cta_clientes.cod_persona%type;
  v_nom_ente        ge_entes.descripcion%type;
  v_dir_mail_deb    ba_personas.dir_correo%type;
  v_nom_cli_debito  ba_personas.nom_completo%type; 
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');
  v_texto         varchar2(4000);
  v_texto_detalle clob;
  v_adjunto       clob;
  v_adjunto_error clob;
  v_cabecera      clob;
  v_nom_adj varchar2(500);
  v_total_procesado number ;
  v_total_error number ;

  -- Variables para mail
  v_conn     utl_smtp.connection;
  v_asunto   VARCHAR2(2000);                
  v_mje_mail LONG;

  --GAC 24/05/2016 Se agrega membrete, a pedido del usuario solicitante
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  v_membrete LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P',c_dir_mail);
  --
                         
  CURSOR g_ente is
    select a.cod_ente, a.nro_cta_debito
      from ta_acr_gourmet a
     where a.fec_recepcion = v_fec_actual
       and a.estado = 'A'
       and a.nro_cta_debito is not null
  group by a.cod_ente, a.nro_cta_debito
  order by a.cod_ente, a.nro_cta_debito;

  CURSOR c_rec(v_ente ge_pag_recaudaciones.cod_ente%TYPE, v_cta_debito ge_cuentas.nro_cuenta%TYPE) is
     select * /* distinct(a.cod_ente)*/
      from ta_acr_gourmet a
     where a.fec_recepcion = v_fec_actual
       and a.estado = 'A'
       and a.nro_cta_debito is not null
       and a.cod_ente = v_ente
       and a.nro_cta_debito = v_cta_debito
     order by a.cod_ente;

     -- Agregamos mascara para Nro TC, XXXX XXXX XXXX XXXX
     function lf_fmt_nro_tarjeta(p_nro_tarjeta ta_acr_gourmet.nro_cta_debito%type) return varchar2 is          
       v_resultado string(20);
       v_numero    string(20);
       v_cant      number(2);
     begin  
        v_numero := p_nro_tarjeta;
        v_cant:=1;
        for i in 1..4 loop
          v_resultado := v_resultado ||substr(v_numero,v_cant,4) ;
          v_cant:= v_cant+4;
          if v_cant < 16 then
            v_resultado := v_resultado || ' ';
          end if;    
        end loop;     
        return v_resultado;   
     end lf_fmt_nro_tarjeta;
begin
  begin
    -- Envío de mail al titular de cta crédito.
    for a in g_ente loop
      --GAC 01/06/2016 Se agrega membrete, a pedido del usuario solicitante
       v_nom_ente        := fue_obt_nom_ente(a.cod_ente);
       v_cod_per_debito  := fug_obt_cli_principal(a.nro_cta_debito);
       v_dir_mail_deb    := fug_obt_parentes(a.cod_ente,'DIR_MAIL_TC');
       if v_dir_mail_deb is null then 
           v_dir_mail_deb    := fug_obt_dir_mail_per(v_cod_per_debito);
       end if;

       v_nom_cli_debito  := fue_obt_nom_persona(v_cod_per_debito);
       
       v_texto_detalle := null; 
       v_adjunto       := null;
       v_adjunto_error := null;
       v_total_procesado := 0;
       v_total_error := 0;
       
       for b in c_rec(a.cod_ente, a.nro_cta_debito) loop     
          
        v_total_procesado := v_total_procesado + nvl(b.monto, 0);
          
        v_adjunto := v_adjunto || v_nom_cli_debito || '.' || chr(9) ||
                     to_char(b.fec_recepcion, 'DD/MM/YYYY') || chr(9)|| 
                     b.nro_cta_debito || chr(9) || lf_fmt_nro_tarjeta(b.nro_tarjeta) ||
                     chr(9) || b.monto || chr(9) || b.nro_archivo || 
                     chr(9)||chr(10);
       
    
       end loop;
       
       if v_adjunto is not null then
        
         v_cabecera := 'Cliente' || chr(9) || 'Fecha' || chr(9) ||  'Cuenta de débito' || chr(9) ||
                  'Nro Tarjeta' || chr(9) || 'Monto' || chr(9) || 'Nro. Archivo' || chr(9)||chr(10);

        
          
          v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                             v_cabecera || chr(10) || v_adjunto || chr(10)||
                             chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||v_total_procesado||chr(10);
        end if;
       
        v_texto := '<br><br>
               <br><br>
                 Estimado Cliente: '|| upper(v_nom_cli_debito) ||'
               <br><br>
                 Le informamos que se realiz&oacute; el proceso de Acreditaciones Gourmet Card correspondiente a la fecha ' ||
                         to_char(v_fec_actual, 'DD/MM/YYYY') || ',' || ' en el cual se realizaron las operaciones detalladas en el archivo adjunto.
               <br><br>
                 Atentamente.
               <br><br>
               <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
               <br><br>
               <br><br>'; 
 
  
           --GAC 01/06/2016 Se agrega membrete, a pedido del usuario solicitante
          v_nom_adj := 'ACR_GOU_' || a.cod_ente || '_' ||
                       to_char(v_fec_actual, 'DDMMYY');
          
          v_asunto   := 'Acreditaciones Gourmet';
          v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                        chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;
                        
          if v_dir_mail_deb  is not null then
                        
            v_conn     := it_mail.begin_mail(c_dir_mail,
                                             v_dir_mail_deb, 
                                             v_asunto,
                                             IT_MAIL.MULTIPART_MIME_TYPE);
              
            it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
            
            it_mail.begin_attachment(v_conn,
                                     'text/plain',
                                     false,
                                     v_nom_adj ||'.xls');
            
            v_texto_detalle := chr(10) || CHR(9) || CHR(9) ||
                               'SERVICIO DE ACREDITACIONES GOURMET CARD' || CHR(10) ||
                               v_texto_detalle;
            
            it_mail.write_text(v_conn, v_texto_detalle);
            
            it_mail.end_mail(v_conn);
            
          end if;

    end loop;

  EXCEPTION
    when others then
     raise_application_error(-20000,'PRT_ENV_MAI_GOURMET '||sqlerrm);
  END;
end;
/

