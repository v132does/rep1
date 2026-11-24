CREATE OR REPLACE TRIGGER IT.TA_GE_MOVIMIENTOS
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_MOVIMIENTOS
 FOR EACH ROW

DECLARE
R_RETENCION AH_RETENCIONES%ROWTYPE;
r_limite    LC_RETENCIONES%ROWTYPE;
v_tip_transaccion varchar2(1):='D';      
v_est_modulo ba_modulos.estado%type;
BEGIN
    if (inserting and :new.estado='N') or (updating and :old.estado<>:new.estado and :new.estadO='N') then
        if :new.COD_RETENCION is not null and :new.FEC_FIN_RETENCION is not null and :new.reversado = 'N'
        and :new.cod_modulo in (3,4,5) and :new.nro_cuenta is not null then
           R_RETENCION.COD_MODULO := :new.COD_MODULO;
           R_RETENCION.COD_MODALIDAD := :new.COD_MODALIDAD;
           R_RETENCION.COD_OFICINA := :new.COD_OFICINA;
           R_RETENCION.NRO_CUENTA := :new.NRO_CUENTA;
           R_RETENCION.COD_OFI_ORIGEN := :new.COD_OFI_ORIGEN;
           R_RETENCION.NRO_DOCUMENTO := :new.NRO_DOCUMENTO;
           R_RETENCION.COD_RETENCION := :new.COD_RETENCION;
           R_RETENCION.COD_MONEDA := :new.COD_MONEDA;
           R_RETENCION.MONTO := :new.MONTO;
           R_RETENCION.FEC_INICIO := :new.FECHA;
           R_RETENCION.FEC_FINAL := :new.FEC_FIN_RETENCION;
           R_RETENCION.COD_USUARIO := :new.COD_USUARIO;
           IF :new.cod_transaccion = 613 then -- deposito en efectivo en TAS, se considera detallado
               R_RETENCION.DETALLADO := 'S';
           ELSE
               R_RETENCION.DETALLADO := 'N';
           END IF;   
           R_RETENCION.LIBERADO := 'N';            
           R_RETENCION.LIB_POSTERIOR := 'N';
           R_RETENCION.SAL_RETENIDO := :new.MONTO;
           --VAlida si es una reversa 
           IF :new.MONTO < 0 AND :new.COD_RETENCION IS NOT NULL AND :new.FEC_FIN_RETENCION is not null and (:new.COD_USUARIO like '%APICAJERO%')  THEN
              BEGIN
                DELETE FROM ah_retenciones AH
                 WHERE AH.NRO_CUENTA    = :new.nro_cuenta
                   AND AH.NRO_DOCUMENTO = :new.NRO_DOCUMENTO
                   AND AH.COD_RETENCION = :new.COD_RETENCION
                   AND AH.FEC_FINAL     = :new.FEC_FIN_RETENCION
                   AND AH.LIBERADO      = 'N';
                 COMMIT; 
               EXCEPTION 
                WHEN OTHERS THEN 
                  NULL;  
               END;
           ELSE
               PRA_INS_AH_RETENCION(R_RETENCION);
           END IF;

        elsif :new.COD_RETENCION is not null and :new.FEC_FIN_RETENCION is not null
         and :new.reversado = 'N' and :new.cod_modulo =7 and :new.nro_cuenta is not null and :new.cod_transaccion =760
         and nvl(:new.monto,0) > 0 then
           r_limite.COD_MODULO := :new.COD_MODULO;
           r_limite.COD_MODALIDAD := :new.COD_MODALIDAD;
           r_limite.COD_OFICINA   := :new.COD_OFICINA;
           r_limite.NRO_CUENTA    := :new.NRO_CUENTA;
           r_limite.COD_OFI_ORIGEN:= :new.COD_OFI_ORIGEN;
           r_limite.NRO_boleta    := :new.NRO_DOCUMENTO;
           r_limite.COD_RETENCION := :new.COD_RETENCION;
           r_limite.COD_MONEDA    := :new.COD_MONEDA;
           r_limite.MONTO         := :new.MONTO;
           r_limite.FEC_INICIO    := :new.FECHA;
           r_limite.FEC_FIN       := :new.FEC_FIN_RETENCION;
           r_limite.COD_USUARIO   := :new.COD_USUARIO;
           r_limite.LIBERADO      := 'N';
           r_limite.DETALLADO     := 'N';
           r_limite.LIB_anticipada:= 'N';
           r_limite.cod_tip_referencia:= 999;--ref gral
           r_limite.nro_referencia    := 0;
           --WA:Se inserta para Liberar Retencion de Cheques Gs, si existiesen
           r_limite.sal_retenido    := :new.monto;
           r_limite.cotizacion    := :new.cotizacion;
           PAL_CAM.PR_INS_LC_RETENCIONES(r_limite);
       elsif :new.COD_RETENCION is not null and :new.FEC_FIN_RETENCION is not null
         and :new.reversado = 'N' and :new.cod_modulo = 6 and :new.cod_transaccion in (607, 610, 632) then --CRO-HO-CROCPCCB-13/08/15 Se inserta bloque para cargar retencion en caso de ser un cobro de préstamos con cheque cargo otros bancos
           R_RETENCION.COD_MODULO     := :new.COD_MODULO;
           R_RETENCION.COD_MODALIDAD  := :new.COD_MODALIDAD;
           R_RETENCION.COD_OFICINA    := :new.COD_OFICINA;
           R_RETENCION.NRO_CUENTA     := :new.NRO_CUENTA;
           R_RETENCION.COD_OFI_ORIGEN := :new.COD_OFI_ORIGEN;
           R_RETENCION.NRO_DOCUMENTO  := :new.NRO_DOCUMENTO;
           R_RETENCION.COD_RETENCION  := :new.COD_RETENCION;
           R_RETENCION.COD_MONEDA     := :new.COD_MONEDA;
           R_RETENCION.MONTO          := :new.MONTO;
           R_RETENCION.FEC_INICIO     := :new.FECHA;
           R_RETENCION.FEC_FINAL      := :new.FEC_FIN_RETENCION;
           R_RETENCION.COD_USUARIO    := :new.COD_USUARIO;
           R_RETENCION.DETALLADO 	    := 'N';
           R_RETENCION.LIBERADO       := 'N';            
           R_RETENCION.LIB_POSTERIOR  := 'N';
           R_RETENCION.SAL_RETENIDO   := :new.MONTO;
           PRA_INS_AH_RETENCION(R_RETENCION);
        end if;
        --COBRADOR 24X7
        if nvl(fug_obt_pardinamico('ACT_COB_24X7'),'N') = 'S' then --Solo si está Activo COB 24x7.
            if nvl(PAE_CNF.G_PROGRAMA,'x') not in ('GPPAGSUE','GPPROFIN') then -- No debe ejecutar en el Cierre ni Pago Sueldo.
               v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(4);
               if v_est_modulo = 2 then -- Solo ejecutar con modulo Abierto.
                  if  :new.reversado ='N' and :new.estado = 'N' then   
                      if FUP_EXI_GRU_TRANSAC(fug_obt_pardinamico('COD_GRU_TRA_COBRADOR24X7'),:new.cod_tra_padre,:new.cod_mod_padre, :new.cod_mad_padre) = 'S' then --Solo si está en el Gru. de Trans. 201.
                         PRG_ACT_TAB_CTA_ATRASOS(:new.NRO_CUENTA,'N',:new.fecha,:new.hora,:new.cod_usuario,:new.cod_tra_padre);
                      end if;
                  else
                      PRG_ACT_TAB_CTA_ATRASOS(:new.NRO_CUENTA,'S',:new.fecha,:new.hora,:new.cod_usuario,:new.cod_tra_padre);  
                  end if;      
               end if;
             end if; 
        end if;  
    end if;
END;
/
