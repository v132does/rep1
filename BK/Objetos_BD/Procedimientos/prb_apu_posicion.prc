CREATE OR REPLACE PROCEDURE IT."PRB_APU_POSICION"
is
   --- Realiza apuntes en asientos futuros/traslada asiento de oficina origen a oficina destino 31
   --- Realizado por: Alejandro Ferreira - 30/09/2011
   --- Propiedad exclusiva del BBVA
   --------------------------------------------------------
---Variables--------
v_sal_deudor     number(18,2) :=0;
v_sal_acrededor  number(18,2) :=0;
v_fecha          date;
v_cod_oficina    ba_oficinas.cod_oficina%TYPE;
v_cod_cargo      cb_gas_diferidos.cod_cargo%TYPE;
v_mto_asiento    number(18,2) := 0;
v_nro_linea      cb_asi_futuros_det.nro_linea%TYPE := 1;
v_cod_rub_inter  number :=0;
v_mto_guaranies  number(18,2) :=0;
v_tip_movimiento char :=NULL;
v_mto_mon_rubro  number(18,2) :=0;
v_nro_asiento     cb_asi_futuros.nro_asiento%TYPE;
v_descripcion    varchar2(50):='Cuadre Automatico de Posicion de Cambios';
v_est_proceso ba_modulos.estado%type;

---Cursor Fuente---
cursor pos_cambio is
select bv.cod_divisa,
       bv.cod_oficina,
       bv.ofi_descripcion,
       bv.cod_moneda,
       bv.total_activo,
       bv.total_pasivo,
       bv.saldo_deudor,
       bv.saldo_acreedor,
       bv.cotiz,
       bv.cv_Guaranies
from bv_pos_cam_ajuste bv
where (saldo_acreedor <> 0 or saldo_deudor <> 0) and cod_oficina <> 31;
---------------------
begin

   -- Controlar si el módulo 2 se encuentra cerrado (debe utilizar balance cerrado)
   v_est_proceso := PAE_CNF.fu_obt_est_modulo(2);
   if nvl(v_est_proceso,4) <> 4 then
      raise_application_error(-20000,
      'El modulo 2 debe estar cerrado para trasladar la posicion de cambios');
   end if;
   
for i in pos_cambio loop
    v_cod_oficina := i.cod_oficina;
    v_mto_guaranies := i.cv_guaranies;
    v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(2);
    v_nro_asiento := fub_obt_sig_nro_asi_futuro(v_cod_oficina, v_fecha);
    v_sal_acrededor := abs(i.saldo_acreedor);
    v_sal_deudor := i.saldo_deudor;
    v_mto_asiento := abs(v_mto_guaranies);

    if (v_sal_acrededor <> 0 or v_sal_deudor <> 0) and i.cod_oficina <> 31 then
    -----Validaciones del Tipo de movimiento----
    if v_sal_acrededor > 0 and v_sal_deudor <=0 then
       v_tip_movimiento := 'D';
      else
       v_tip_movimiento := 'C';
    end if;
    ---------------------
        -----obtiene el codigo de rubro interOficina 31 segun moneda------
        v_cod_rub_inter := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,i.cod_moneda,31);
        v_cod_rub_inter :=  substr(v_cod_rub_inter, 1, 10) || ltrim(to_char(31, '000'))
        ||substr(v_cod_rub_inter, 14, 2);                                            
        ----Inserta Cabecera----    
              INSERT INTO cb_asi_futuros
                 (fecha, cod_oficina, nro_asiento, cod_usuario, cod_modulo, cod_modalidad, cod_cargo,
                  tot_control)
              VALUES
                 (v_fecha, v_cod_oficina, v_nro_asiento, USER, 2, 21,  v_cod_cargo,round(v_mto_asiento*2));
        ----Trasnlada saldo acrededor o deudor dependiendo de la fuente----
            if v_tip_movimiento = 'D' then
               v_mto_mon_rubro := v_sal_acrededor;
              else
               v_mto_mon_rubro := v_sal_deudor;
            end if;
        ----Inserta Detalle 1----
              INSERT INTO cb_asi_futuros_det
                 (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local,
                  descripcion, mto_mon_rubro, val_cotizacion)
              VALUES
                 (v_fecha, v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_inter, v_tip_movimiento, v_mto_asiento,
                  v_descripcion, v_mto_mon_rubro,
                  null);
        ----Cambio el tipo de movimiento para tener Debito y Credito en el Detalle del asiento---
              if v_tip_movimiento = 'C' then
                 v_tip_movimiento := 'D';
                else
                 v_tip_movimiento := 'C';
              end if;
        ----Obtiene el codigo de rubro interOficina 31 con moneda GS------
        v_cod_rub_inter := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,'GS',31);
        v_cod_rub_inter :=  substr(v_cod_rub_inter, 1, 10) || ltrim(to_char(31, '000'))
        ||substr(v_cod_rub_inter, 14, 2);
        ----Trasnlada saldo acrededor o deudor dependiendo de la fuente----
            if v_tip_movimiento = 'D' then
               v_mto_mon_rubro := v_sal_acrededor;
              else
               v_mto_mon_rubro := v_sal_deudor;
            end if;
        ----Inserta Detalle 2----
              INSERT INTO cb_asi_futuros_det
                 (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local,
                  descripcion, mto_mon_rubro, val_cotizacion)
              VALUES
                 (v_fecha, v_cod_oficina, v_nro_asiento, v_nro_linea + 1, v_cod_rub_inter, v_tip_movimiento,
                  v_mto_asiento,v_descripcion,v_mto_mon_rubro,
                  null);
                  
        -----##################################---------          
        -----Traslado de montos a la oficina 31---------
         v_nro_asiento := fub_obt_sig_nro_asi_futuro(31, v_fecha);
        -----obtiene el codigo de rubro interOficina------
        v_cod_rub_inter := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,i.cod_moneda,i.cod_oficina);
        v_cod_rub_inter :=  substr(v_cod_rub_inter, 1, 10) || ltrim(to_char(i.cod_oficina, '000'))
        ||substr(v_cod_rub_inter, 14, 2);
        ---Cambiamos la oficina actual por la oficina 31 para el traslado---
        v_cod_oficina := 31;
                                                    
        ----Inserta Cabecera----    
              INSERT INTO cb_asi_futuros
                 (fecha, cod_oficina, nro_asiento, cod_usuario, cod_modulo, cod_modalidad, cod_cargo,
                  tot_control)
              VALUES
                 (v_fecha, v_cod_oficina, v_nro_asiento, USER, 2, 21,  v_cod_cargo,round(v_mto_asiento*2));
        ----Trasnlada saldo acrededor o deudor dependiendo de la fuente----
            if v_tip_movimiento = 'D' then
              -- v_mto_mon_rubro := v_sal_acrededor;
               v_mto_mon_rubro := v_sal_deudor;
              else
               v_mto_mon_rubro := v_sal_acrededor;
            end if;
        ----Inserta Detalle 1----
              INSERT INTO cb_asi_futuros_det
                 (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local,
                  descripcion, mto_mon_rubro, val_cotizacion)
              VALUES
                 (v_fecha, v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_inter, v_tip_movimiento, v_mto_asiento,
                  v_descripcion,v_mto_mon_rubro,
                  null);
        ----Cambio el tipo de movimiento para tener Debito y Credito en el Detalle del asiento---
              if v_tip_movimiento = 'C' then
                 v_tip_movimiento := 'D';
                else
                 v_tip_movimiento := 'C';
              end if;
        ----Obtiene el codigo de rubro interOficina con moneda GS------
        v_cod_rub_inter := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,'GS',i.cod_oficina);
        v_cod_rub_inter :=  substr(v_cod_rub_inter, 1, 10) || ltrim(to_char(i.cod_oficina, '000'))
        ||substr(v_cod_rub_inter, 14, 2);
        ----Trasnlada saldo acrededor o deudor dependiendo de la fuente----
            if v_tip_movimiento = 'D' then
               v_mto_mon_rubro := v_sal_deudor;
              else
               v_mto_mon_rubro := v_sal_acrededor;
            end if;
        ----Inserta Detalle 2----
              INSERT INTO cb_asi_futuros_det
                 (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local,
                  descripcion, mto_mon_rubro, val_cotizacion)
              VALUES
                 (v_fecha, v_cod_oficina, v_nro_asiento, v_nro_linea + 1, v_cod_rub_inter, v_tip_movimiento,
                  v_mto_asiento,v_descripcion,v_mto_mon_rubro,
                 null);       
        
    end if;


end loop;
 EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR : ofi '|| v_cod_oficina || ' GS ' || v_mto_guaranies ||'  '||SQLERRM );
 
end PRB_APU_POSICION;
/

