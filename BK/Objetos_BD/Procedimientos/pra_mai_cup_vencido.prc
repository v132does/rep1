create or replace procedure it.PRA_MAI_CUP_VENCIDO is

   
   c_dir_mail         ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com' ;
   v_fec_actual       date default pag_cal.fu_obt_fec_actual(1);
   v_cod_persona      ba_personas.cod_persona%type;
      
   v_cod_per_par      ge_par_dinamicos.val_parametro%type;
   v_dest_mail        ge_par_dinamicos.val_parametro%type;
   
   -- Variables para mail
   v_conn     utl_smtp.connection;
   v_asunto   VARCHAR2(2000);
   v_mje_mail LONG; 
 
  V_DETALLE  LONG := '';
  
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  V_CABECERA LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P',c_dir_mail);
  --
  
   CURSOR c_cob(p_per varchar2) is
       select  cd.fec_apertura,
             cd.capital,
             cd.serie,
             CU.NRO_CUPON,
             CU.FEC_VENCIMIENTO,      
             cd.cod_moneda,
             nvl(cu.mto_interes, 0) mto_interes,
             CU.NRO_CUENTA,
             cd.nro_cta_credito,
             CU.ROWID linea
      from AH_CUPONES CU, AH_CTA_CERTIFICADOS CD, ge_cta_clientes a
     where CD.NRO_CUENTA = CU.NRO_CUENTA
       AND CD.ESTADO NOT IN ('A', 'T', 'P', 'C', 'X')
       AND CU.ESTADO = 'E'
       and CU.FEC_VENCIMIENTO <= pag_cal.fu_obt_fec_actual(1)
       and a.nro_cuenta = cd.nro_cuenta
       and a.relacion = 'P'
       and a.cod_persona in p_per;


   BEGIN
 
     select fug_obt_pardinamico('MAIL_VENC_CDA_PER') 
       into v_cod_per_par
       from dual;
       
     select fug_obt_pardinamico('MAIL_VENC_CDA_DESTINATARIO') 
       into v_dest_mail
       from dual;
       
     for k in c_cob(v_cod_per_par) loop
                           
         BEGIN 
                 V_DETALLE :=   '<br><br>
                                  Estimado :
                                 <br><br>
                                  Le informamos que en la fecha '||v_fec_actual||' venció un cupón de interes del cliente: 
                                  '||v_cod_persona||' - '||fue_obt_nom_persona(v_cod_persona)||'.  
                                  <br><br>
                                  El detalle de la operación: 
                                  <br><br>
                                  Nro Cuenta: '|| k.nro_cuenta||
                                  '<br>
                                  Fecha de Constitución del CDA: ' || to_char(k.fec_apertura,'dd/mm/yyyy') ||
                                  '<br>
                                  Capital: ' || k.capital ||
                                  '<br>
                                  Serie del CDA: ' || k.serie||'.
                                  <br>
                                  Nro del Cupón: ' || k.nro_cupon||'.
                                  <br>
                                  Fecha de vencimiento del Cupón: ' || to_char(k.fec_vencimiento,'dd/mm/yyyy') ||'.
                                  <br>
                                  Moneda: ' || k.cod_moneda ||'.
                                  <br>
                                  Monto del Cupón de Interes: ' || k.mto_interes ||'.
                                  <br>
                                  Nro. Cuenta Acreditada: ' || nvl(k.nro_cta_credito,'-') ||'.
                                  <br>
                                  <br>
                                  Atentamente.
                                  <br><br>
                                  <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                                 <br><br> ';

                
                v_asunto   := 'Vencimiento de Cupones';
                v_mje_mail := V_CABECERA || chr(10) || chr(10) || chr(10) || V_DETALLE ||
                              chr(10) || chr(10) || chr(10) || V_FIN|| chr(10) ||V_PIE;
                v_conn     := it_mail.begin_mail(c_dir_mail,
                                                 v_dest_mail,
                                                 v_asunto,
                                                 IT_MAIL.MULTIPART_MIME_TYPE);
                                                 
                it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

               it_mail.end_mail(v_conn);
   
           
           EXCEPTION
             when others then
               INSERT INTO ge_ra_log_mail
                 (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                VALUES
                 (SYSDATE, v_asunto, v_dest_mail, v_asunto, v_asunto, '', '');
                COMMIT;
           END;
      commit;
     end loop;
  
end PRA_MAI_CUP_VENCIDO;
/

