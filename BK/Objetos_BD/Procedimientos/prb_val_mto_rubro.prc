CREATE OR REPLACE PROCEDURE IT.PRB_VAL_MTO_RUBRO
IS
/* OMM 05/10/2015- Valida el monto minimo de diferencia con el saldo anterior por rubro, 
   y envía mail si cancela el inicio de día para avisar a Contablidad.
   Además se agrega el proceso de validación de estado de modulo para reemplazar el programa
   en el inicio de día contable  */
 v_sal_anterior  cb_sal_consolidados.sal_mon_loc_ant%type ;
 v_sal_actual    cb_sal_consolidados.sal_mon_loc_ant%type ;
 v_fec_actual    ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(2) ;
 v_rubro         cb_rubros.cod_rubro%type;
 c_dir_mail      ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');--'infobbva@bbva.com';
 v_dir_mail_deb  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DIR_COR_CONTABILIDAD') || fug_obt_pardinamico('CAM_MAR_DIR_EP');
 v_texto         varchar2(4000);
 v_tex_tot       varchar2(1000);
 v_adjunto       clob ;
 v_error         varchar2(1) := 'N';
 v_cantidad      number := 0;
 v_conn          utl_smtp.connection;
 ex_salir        exception;
 v_cal_saldo     number := 0;
 v_cal_total     number := 0;
 v_cot_usd       ge_cotizaciones.val_conversion%type := 0 ;
 v_cot_eur       ge_cotizaciones.val_conversion%type := 0 ;
 v_mto_total     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MTO_MAX_DIF_CONTABLE') ;
 crlf            VARCHAR2(2)  := chr(13)||chr(10);
-- Cursor de verificación de los montos maximos de diferencias por rubro
CURSOR rubros IS
      Select r.significado, r.val_minimo rubro, r.val_maximo mto_maximo
        from ba_cod_referencias r
      where r.dominio = 'VAL_RUBRO' ;
      
-- Cursor de verificación de los totales con posición de camibios
CURSOR total IS
      select t.cod_divisa, t.cod_moneda, sum(t.total_activo) total_activo, sum(t.total_pasivo) total_pasivo,
      case when sum(nvl(t.saldo_deudor,0) + nvl(t.saldo_acreedor,0)) < 0 then 0
           else sum(nvl(t.saldo_deudor,0) + nvl(t.saldo_acreedor,0))
           end saldo_deudor,
       case when sum(nvl(t.saldo_deudor,0) + nvl(t.saldo_acreedor,0)) > 0 then 0
            else sum(nvl(t.saldo_deudor,0) + nvl(t.saldo_acreedor,0))
            end saldo_acreedor,
      sum(t.posicion_me) posicion_me
      from bv_pos_cambio t
      where t.cod_moneda in ('USD', 'EUR')
      group by t.cod_divisa, t.cod_moneda ;

BEGIN
   -- Cursor para validar los montos de los rubros con el saldo anterior
   FOR rub IN rubros LOOP
      v_rubro := rub.rubro ;

      Begin
         Select abs(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)), 
                abs(nvl(s.sal_mon_loc_ant,0)) sal_anterior
            into v_sal_actual, v_sal_anterior
          from cb_sal_consolidados s
          where s.cod_rubro = v_rubro
            and s.mes = to_char(v_fec_actual, 'MM')
            and s.ano = to_char(v_fec_actual, 'YYYY');
      exception
         when others then
            v_sal_actual   := 0 ;
            v_sal_anterior := 0 ;
      end;

      if abs(v_sal_actual - v_sal_anterior) > nvl(rub.mto_maximo,0) then
         -- En caso de superar la diferencia parametrizada debe enviar mail a contabilidad avisando y cancelar el proceso
         v_error     := 'S' ;
         v_cantidad  := v_cantidad + 1;
         v_adjunto := v_adjunto || to_char(v_rubro,'999999999999999999')  || chr(9) || rub.significado || chr(9) || 
                      to_char(v_sal_anterior,'999G999G999G999G999') || chr(9) ||
                      to_char(v_sal_actual,'999G999G999G999G999') || chr(9)  || 
                      to_char(v_sal_actual - v_sal_anterior,'999G999G999G999G999') || chr(9)  || 
                      to_char(rub.mto_maximo,'999G999G999G999G999')|| chr(10);
      end if ;

   end loop;
   
   -- Cursor para validar el monto total del Activo, Pasivo y la Posición de Cambios
   v_cal_total := 0;
   v_cot_eur   := pag_gen.FU_OBT_COTIZACION('EUR', v_fec_actual) ;
   v_cot_usd   := pag_gen.FU_OBT_COTIZACION('USD', v_fec_actual) ;
   FOR j IN total LOOP
      v_cal_saldo := 0;
      if nvl(j.saldo_deudor,0) <> 0 then
          v_cal_saldo := (j.saldo_deudor*-1) - j.posicion_me;
      end if;
      if nvl(j.saldo_acreedor,0) <> 0 then
          v_cal_saldo := (j.saldo_acreedor*-1) - j.posicion_me;
      end if;
      if v_cal_saldo <> 0 then
         if j.cod_moneda = 'EUR' then
            v_cal_saldo := trunc((v_cot_eur / v_cot_usd) * v_cal_saldo) ;
         end if ;
         v_cal_total := v_cal_total + abs(v_cal_saldo) ;
      end if ;
   END LOOP;
   
   -- Marca como error si supera el monto maximo configurado en el total de posición
   if v_cal_total > 0 and to_number(v_mto_total) < v_cal_total then
      v_error := 'S' ;
      v_tex_tot := 'Se superó el limite de diferencia en la posición de cambio, en fecha: '||v_fec_actual||
                   ' con un saldo total de diferencia (USD + EUR) de: '|| to_char(v_cal_total,'999G999G999G999G999')||
                   ' se recuerda que el monto maximo configurado en el Parametro Dinamico "MTO_MAX_DIF_CONTABLE" es: '||
                   to_char(v_mto_total,'999G999G999G999G999') ;
   end if ;
   
   if v_error = 'S' then 
      
      if v_cantidad > 0 then
         Begin
           v_texto := 'Se comunica que el proceso de inicio de día contable ha sido cancelado'||crlf||
                      'En fecha calendario contable: '||v_fec_actual||crlf||
                      'Se adjunta detalle de los rubros y saldos con diferencias mayores a los parametrizados' ||crlf||
                      'Se encontraron la cantidad de '||v_cantidad|| ' diferencias.   '||crlf|| crlf||
                      v_tex_tot;
                        
           v_adjunto := chr(9)||'RUBROS CON DIFERENCIAS MAYORES A LAS PARAMETRIZADAS'||chr(9)||chr(10)||
                        'RUBRO' || chr(9) || 'DESCRIPCION' || chr(9) || 'SALDO_ANTERIOR' || chr(9) ||
                        'SALDO_ACTUAL' || chr(9) || 'DIFERENCIA' || chr(9) || 'MTO_MAXIMO' || chr(10)||
                        v_adjunto;


           v_conn     := it_mail.begin_mail(c_dir_mail,
                                         v_dir_mail_deb,
                                         'CANCELACIÓN DEL PROCESO DE INICIO DE DIA CONTABLE',
                                         IT_MAIL.MULTIPART_MIME_TYPE);   
                                                          
           it_mail.attach_text(v_conn, v_texto, 'text/html');
        
           it_mail.begin_attachment(v_conn,
                                 'text/plain',
                                 false,
                                 'DIF_RUBRO_'||to_char(v_fec_actual, 'DDMMYY')|| '.xls');

           it_mail.write_text(v_conn, v_adjunto);
        
           it_mail.end_mail(v_conn);
         exception
            when others then
               null ;
         end;
      else
          Begin
             it_mail.mail(c_dir_mail,
                          v_dir_mail_deb,
                          'CANCELACIÓN DEL PROCESO DE INICIO DE DIA CONTABLE - Solo Dif. Total',
                          v_tex_tot);  
          exception
            when others then
               null ;
          end;
      end if ;
      
      raise ex_salir;
   
   end if ;

exception
   when ex_salir then
       raise_application_error(-20000,'PRB_VAL_MTO_RUBRO, Error tratado por diferencias, ya se envio un mail avisando a Contabilidad.' 
                                      ||' No se debe continuar el inicio Contable');
   when others then
      raise_application_error(-20000,'Error en PRB_VAL_MTO_RUBRO, al tratar de validar el rubro: '||v_rubro);
END;
/

