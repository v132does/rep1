CREATE OR REPLACE TRIGGER IT.TB_AP_PAGOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON AP_PAGOS
 FOR EACH ROW


DECLARE

/* Valida que la fecha de Pago se encuentre en el Rango de Requerimientos */
PROCEDURE LP_VAL_FEC_PAGO
 (P_COD_REQUERIMIENTO IN AP_REQUERIMIENTOS.COD_REQUERIMIENTO%TYPE
 ,P_FEC_PAGO IN AP_PAGOS.FECHA%TYPE
 );

/* Valida que la fecha de Pago se encuentre en el Rango de Requerimientos */
PROCEDURE LP_VAL_FEC_PAGO
 (P_COD_REQUERIMIENTO IN AP_REQUERIMIENTOS.COD_REQUERIMIENTO%TYPE
 ,P_FEC_PAGO IN AP_PAGOS.FECHA%TYPE
 )
 IS

V_FEC_INICIO AP_REQUERIMIENTOS.FEC_INICIO%TYPE;
V_FEC_FIN AP_REQUERIMIENTOS.FEC_FIN%TYPE;
BEGIN
   select fec_inicio, fec_fin
   into v_fec_inicio, v_fec_fin
   from ap_requerimientos
   where cod_requerimiento = p_cod_requerimiento;
   --if p_fec_pago <= v_fec_inicio then
   if p_fec_pago not between v_fec_inicio and v_fec_fin then
      raise_application_error(-20000,
      'La fecha de Pago no se encuentra dentro del Rango de Fechas del Requerimiento');
   end if;
exception
   when no_data_found then
      raise_application_error(-20000,
      'No existe el Requerimiento: '||to_char(p_cod_requerimiento));
   /*when others then
      raise_application_error(-20001,
      'lp_val_fec_pago '||sqlerrm);    */


END;
Begin
declare
    v_categoria ba_usuarios.categoria%type;
Begin
    if inserting then
        -- Verificar si usuario es Supervisor Tecnología
        v_categoria := fuy_obt_cat_usuario(:new.cod_usuario);
        if v_categoria <> 'ST' then
            raise_application_error(-20000,
            'Usuario debe ser Supervisor de Tecnologia');
        end if;
        --Validar que la fecha de pago se encuentre en el rango
        --de fechas de Requerimientos
        lp_val_fec_pago(:new.cod_requerimiento, :new.fecha);
    elsif updating then
        -- Verificar si usuario es Supervisor Tecnología
       if :old.cod_usuario <> :new.cod_usuario then
          v_categoria := fuy_obt_cat_usuario(:new.cod_usuario);
          if v_categoria <> 'ST' then
             raise_application_error(-20000,
             'Usuario debe ser Supervisor de Tecnologia');
          end if;
       end if;
       if nvl(:new.mto_factura,0) = 0 then
           raise_application_error(-20000,
           'El monto de la factura debe ser ingresado');
       end if;
       if :new.fecha <> :old.fecha then
          --Validar que la fecha de pago se encuentre en el rango
          --de fechas de Requerimientos
          lp_val_fec_pago(:new.cod_requerimiento, :new.fecha);
       end if;

    end if;
End;
End;
/

