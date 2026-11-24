CREATE OR REPLACE FUNCTION IT.fug_es_cta_gnb(
P_NRO_REFERENCIA in varchar2 default null,  -- referencia de la operacion
P_NRO_CUENTA in varchar2,                  -- Nro de Cuenta
P_NRO_DOCUMENTO in varchar2 default null,  -- Nro Documento
P_IMPORTE IN NUMBER default 0,             --importe
P_COD_MONEDA in varchar2 default null,     --moneda
P_DETALLE OUT varchar2                     --Detalle para guardar en referencia
)
    return varchar2

    IS
     -- varibles
     v_fec_actual  date := pag_cal.FU_OBT_FEC_ACTUAL(9);
     v_hor_actual  varchar2(10);
     v_lugar       varchar(200);
     v_hor_max_val_snp_gnb ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'MAX_HOR_VAL_SNP_GNB');
     v_hor_ini_sipap varchar2(10);
     v_retorno     varchar2(100);
     v_resultado    varchar2(3000);
     v_cod_mon_bt varchar2(100);
     v_cod_moneda_bt_it varchar2(100);
     v_importe_cre  number(18,4);
     v_cot_sipap   number(18,4);
     v_cot_mon_original number(18,4);
     v_cot_mon_destino number(18,4);
     v_nom_cliente     varchar2(300);
     v_nro_cta_ori     varchar2(30);
     
      v_tip_cuenta varchar2(3);
      v_tip_cta_bt varchar2(30);
      --v_cod_moneda varchar2(3);
      v_error     varchar2(3000);
      v_hor_ini   varchar2(30);
      v_hor_fin   varchar2(30);
      
/*
Validamos si corresponde a cuenta de GNB
*/

 --procedimiento interno para el registro de los mensajes
   procedure LP_REG_OPERACION(v_nro_documento in varchar2, 
                              v_nro_cuenta in varchar2,
                              v_nro_referencia in varchar2,
                              v_importe in number,
                              v_cod_moneda in varchar2,  --Moneda IT
                              v_cod_moneda_BT in varchar2, --Moneda BT
                              v_cod_moneda_itbt in varchar2, --Moneda BT en IT
                              v_importe_cr in number,
                              v_nom_cliente in varchar2,
                              v_cotizacion in number,
                              v_tip_cuenta in varchar2,
                              v_hor_ini in varchar2,
                              v_hor_fin in varchar2,
                              v_resultado in varchar2) is
   pragma autonomous_transaction; --- para que grabe solo esta transaccion
   v_nro_secuencia number(18);
   begin
     --Borramos de la tabla si ya existe (Corresponde a otro Numero de referencia)
         delete from GE_VAL_CTA_GNB a where a.nro_documento=v_nro_documento and a.nro_cuenta= v_nro_cuenta
           and a.nro_referencia= v_nro_referencia;
            commit;
     if  v_tip_cuenta ='3' then
         v_tip_cta_bt:='Caj.Aho.';
     else
         v_tip_cta_bt:='Cta.Cte.';
     end if;
     
      v_nro_secuencia:= nvl(FUE_OBT_SIG_SECUENCIA('S_NRO_REF_TTR_GNB'),0);
     
      insert into GE_VAL_CTA_GNB
         (nro_cuenta,
         nro_documento,
         cod_mod_it,
         cod_mod_bt,
         fecha, 
         nro_referencia,
         fec_insercion,
         usu_insercion,
         fec_modificacion,
         usu_modificacion,
         imp_ttr, 
         imp_cre,
         nom_cliente, 
         cotizacion,
         mon_cta_cli_it, --moneda it
         mon_cta_cli_bt, --moneda BT
         mon_cta_cli_itbt, --moneda de BT en ITGF
         nro_ref_bt,
         hor_ini,
         hor_fin
         )
      values
         ( v_nro_cuenta,
           v_nro_documento,
           v_tip_cuenta,
           v_tip_cta_bt,
           v_fec_actual,
           v_nro_referencia,
           sysdate,
           user,
           sysdate,
           user,
           v_importe,
           v_importe_cr,
           v_nom_cliente,
           v_cot_sipap,
           v_cod_moneda,  --Moneda IT
           v_cod_moneda_BT, --Moneda BT
           v_cod_moneda_itbt, --Moneda BT en IT
           v_nro_secuencia,
           v_hor_ini,
           v_hor_fin
         );
      commit;
    end;
    
   --procedimiento interno para el registro de los ERRORES
   procedure LP_REG_OPE_ERROR(v_nro_documento in varchar2, 
                              v_nro_cuenta in varchar2,
                              v_nro_referencia in varchar2,
                              v_importe in number,
                              v_cod_moneda in varchar2,  --Moneda IT
                              v_hor_ini in varchar2,
                              v_hor_fin in varchar2,
                              v_error in varchar2) is
   pragma autonomous_transaction; --- para que grabe solo esta transaccion
   begin
      insert into GE_VAL_CTA_GNB_ERR
         (nro_cuenta,
         nro_documento,
         fecha, 
         nro_referencia,
         importe,
         cod_moneda,
         error_dev,
         tipo,
         hor_ini,
         hor_fin)
      values
         ( v_nro_cuenta,
           v_nro_documento,
           v_fec_actual,
           v_nro_referencia,
           v_importe,
           v_cod_moneda,
           v_error,
           'VALCTA',
           v_hor_ini,
           v_hor_fin
         );
      commit;
    end;
     
  begin
     --****** Inicio de Proceso Principal *******
     v_retorno:=null;
     v_resultado:='N';
     v_importe_cre :=0;
     v_cot_sipap:=0;
     v_cod_moneda_bt_it:=0;
     v_nom_cliente:=null;
     v_cod_mon_bt:= null;
     v_nro_cta_ori:= null;
     v_nro_cta_ori:= to_number(P_NRO_CUENTA);
     v_tip_cuenta:= null;
     v_error:= null;
     v_hor_ini:= null;
     v_hor_fin:= null;
     v_hor_ini:= to_char(sysdate,'hh24:mi:ss');
      prg_val_cta_gnb(p_nro_cuenta,                  -- nro de cuenta
                      P_NRO_DOCUMENTO ,  -- nro documento
                      v_resultado,
                      v_cod_moneda_bt_it,
                      v_tip_cuenta ,
                      v_nom_cliente,
                      v_error);
     v_hor_fin:= to_char(sysdate,'hh24:mi:ss');
     v_cod_mon_bt:=pag_mig.FU_OBT_COD_BANTOTAL(v_cod_moneda_bt_it, 'BA_MONEDAS');
     v_importe_cre :=0;
     v_cot_sipap:=0;
     -- 
      if upper(NVL(v_resultado,'N')) ='S' THEN
         --Obtenemos de tabla de cruzamiento
         --v_cod_moneda_bt_it:=pag_mig.FU_OBT_COD_ITGF(v_cod_mon_bt  , 'BA_MONEDAS');
     
          if P_COD_MONEDA <> v_cod_moneda_bt_it then
              --Obtenemos la cotizacion
              
                pas_snp.pr_con_mon_a_moneda( P_COD_MONEDA , --moneda it
                                   v_cod_moneda_bt_it , --moneda BT
                                   P_IMPORTE, --importe ttr:=
                                   v_importe_cre, --importe cre
                                   v_cot_mon_original, --cotizacion original
                                   v_cot_mon_destino  --cotizacion destino
                                 );
                IF v_cot_mon_original = 1 THEN                 
                   v_cot_sipap:= v_cot_mon_destino;           
                ELSIF v_cot_mon_destino= 1 THEN
                   v_cot_sipap:= v_cot_mon_original; 
                END IF;                 
           else
             v_importe_cre:= P_IMPORTE;
      
          end if;
      
     
       --Grabamos en la tabla de Resultados
       
        LP_REG_OPERACION(P_NRO_DOCUMENTO,P_NRO_CUENTA, P_NRO_REFERENCIA, P_IMPORTE,
                         p_cod_moneda,v_cod_mon_bt,v_cod_moneda_bt_it,
                         v_importe_cre,v_nom_cliente,v_cot_sipap, v_tip_cuenta, v_hor_ini, v_hor_fin, v_resultado);
        v_retorno:='S';
              begin
                 select trim('(Es CTA.GNBPY-Moneda :"'|| k.mon_cta_cli_itbt || '" -Tipo: '||k.cod_mod_bt ||
                    ' -Cliente: '||(SUBSTR(k.nom_cliente,1,30))|| ' -Ref.BT:'||K.NRO_REF_BT||')')
                    into P_DETALLE
                     from GE_VAL_CTA_GNB k
                      where k.nro_documento=P_NRO_DOCUMENTO
                        and k.nro_cuenta= P_NRO_CUENTA
                        and k.nro_referencia= P_NRO_REFERENCIA;
               exception
                 when others then
                    P_DETALLE:= null;
               end;
      else
        --Sino es Cta de GNB
        v_retorno:='N';
        IF v_error is not null 
          and ( nvl(instr(v_error, 'accountNotFound'),0)=0 and nvl(instr(v_error, 'documentNotAssociated'),0)=0) then
            LP_REG_OPE_ERROR(P_NRO_DOCUMENTO,P_NRO_CUENTA, P_NRO_REFERENCIA, P_IMPORTE,
                         p_cod_moneda, v_hor_ini, v_hor_fin,v_error);
        end if;
        P_DETALLE:= NULL; 
        
     end if;

     return v_retorno;
end;
/

