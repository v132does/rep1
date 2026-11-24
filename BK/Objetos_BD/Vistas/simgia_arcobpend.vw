create or replace force view it.simgia_arcobpend as
select nvl((select a.cod_persona from ge_cta_clientes a where a.nro_cuenta = gmpen.nro_cuenta and a.relacion like 'P'),0) ACPCLIENTE,
       pai_int.FU_SIM_OBT_TIPO_COMISION(nvl(gmpen.cod_transaccion,0),nvl(substr(gmpen.nro_cuenta,3,2),0), gmpen.cod_moneda) ACPTPCOM,
       0 ACPSTPCOM,
       nvl(substr(gmpen.nro_cuenta,1,2),0) ACPSUC,
       nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(gmpen.nro_cuenta,3,2), gmpen.cod_moneda),0) ACPCTA,
       nvl(substr(gmpen.nro_cuenta,5,6),0) ACPSUB,
       nvl(gmpen.monto,0) ACPMONTO,
       nvl(to_char(gmpen.fecha, 'ddmmyyyy'),0) ACPFEOPE,
       nvl(replace(gmpen.hora,':',''),0) ACPHORA,
       0 ACPBASE,
       case
       when pai_int.FU_SIM_OBT_TIPO_COMISION(nvl(gmpen.cod_transaccion,0),nvl(substr(gmpen.nro_cuenta,3,2),0), gmpen.cod_moneda) = 99 then
          gmpen.cod_transaccion
       else
          0
       end  ACPFEPAG

from GE_MOV_PENDIENTES gmpen;

