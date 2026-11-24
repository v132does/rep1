CREATE OR REPLACE TRIGGER IT.TA_GE_PAR_DINAMICOS
 AFTER UPDATE
 ON GE_PAR_DINAMICOS
 FOR EACH ROW

DECLARE
  PRAGMA AUTONOMOUS_TRANSACTION;
  v_destinatario             tm_mails.env_para%type;
  -- Requerimiento: CNFDEEVO-1
  -- Fecha:         09/11/2015.
  v_fec_ult_dia_hab_anho     ge_calendarios.fec_actual%type;
  v_fec_ult_dia_hab_contable ge_calendarios.fec_actual%type;

BEGIN
   v_destinatario := fug_obt_pardinamico('EMAIL_CAM_OFICINA', 1, 1);
   if updating then
      if((:new.parametro = 'GEN_PRO_CAM_OFI_CUENTAS') and (:new.val_parametro = 'S') and
         (nvl(:old.val_parametro, 'X') != nvl(:new.val_parametro, 'X'))) then
        begin
          it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'), 
                       v_destinatario, 
                       'Proceso de actualización de Oficina '||to_char(sysdate, 'dd/mm/yyyy'), 
                       'Se ha modificado el valor del parámetro dinámico GEN_PRO_CAM_OFI_CUENTAS, '    ||
                       'por ello el día de hoy se ejecutara el "Proceso de actualización de Oficina", '||
                       'este actualiza el código de oficina de las cuentas en base a la oficina del '  ||
                       'gestor, en el caso que no desee ejecutar dicho proceso, modifique el valor '   ||
                       'del parámetro a "N" antes del cierre');
        exception
          when others then
            raise_application_error(-20000, 'Error al notificar por email dicho cambio: '||sqlerrm);
        end;
      end if;
      --
      -- Requerimiento: CNFDEEVO-1
      -- Fecha:         09/11/2015.      
      if((:new.parametro = 'CBN_FEC_ULT_DIA_CIE_ANUAL') and (nvl(:old.val_parametro, 'X') != nvl(:new.val_parametro, 'X'))) then
        begin
          v_destinatario := fug_obt_pardinamico('CBT_ENV_COR_RUBROS');
          it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'), 
                       v_destinatario, 
                       'Inventario Contable (Depósitos Internos y Trading) - Fecha de Modificación: '||to_char(sysdate, 'dd/mm/yyyy'),
                       'Se ha modificado el valor del parámetro dinámico CBN_FEC_ULT_DIA_CIE_ANUAL, '    ||
                       'para la generación del Inventario de Resultado del Depósitos Internos y Trading del último día hábil del año.' ||
                       'Valor Actual: '||nvl(:new.val_parametro, 'X'));
        exception
          when others then
            raise_application_error(-20000, 'Error al notificar por email, CBN_FEC_ULT_DIA_CIE_ANUAL: '||sqlerrm);
        end;
      end if;
      --
      -- Requerimiento: CNFDEEVO-1
      -- Fecha:         09/11/2015.
      if((:new.parametro = 'ANO_FISCAL') and (nvl(:old.val_parametro, 'X') != nvl(:new.val_parametro, 'X'))) then
        begin           
           -- Obtiene la última fecha habil del año.;
           select pag_cal.FU_OBT_FEC_ANT_HAB(to_date('01/01/'||to_char(to_number(:new.val_parametro)+1),'dd/mm/yyyy'),1) 
             into v_fec_ult_dia_hab_anho
             from dual;
           -- Obtengo la fecha del último cierre contable.
           select pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_ult_dia_hab_anho,1) 
             into v_fec_ult_dia_hab_contable
             from dual;   
           -- Actualiza el parametro dinamico.  
           pab_res.pr_act_fec_cie_contable(v_fec_ult_dia_hab_contable);                                                                           
        exception
          when others then
            null;
        end;
      end if;
      commit;
   end if;                
END;
/

