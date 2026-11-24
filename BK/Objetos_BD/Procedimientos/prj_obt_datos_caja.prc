create or replace procedure it.PRJ_OBT_DATOS_CAJA
     (p_nro_caja    in number,   -- nro de caja
      p_cod_moneda  in varchar2, -- codigo de la moneda
      p_cod_oficina out number, -- oficina de la caja
      p_fec_caja    out date,    -- ultima fecha procesada
      p_estado      out number,  -- estado actual
      p_sal_actual  out number,  -- saldo actual de la caja en efectivo
      p_sal_cheques out number,
      p_val_usu_responsable IN VARCHAR2 default 'S')  -- saldo actual en cheques
      is
-- Estados posibles de caja
-- 1 = abierto
-- 2 = cerrado
-- 3 = reabierto
-- 4 = Arqueado
-- 0 = Sin registro
-- -1 = Caja no existe
CURSOR CAJA is
   select FECHA, B.ESTADO ESTADO,
          DECODE(B.ESTADO,2,NVL(MTO_CIERRE,0),
                            NVL(SAL_ACTUAL,0)) SAL_ACTUAL,
          NVL(SAL_CHE_OTR_BCO,0) SAL_CHEQUES
     from CJ_CONTROLES B
    where B.NRO_CAJA   = p_nro_caja
      and B.COD_MONEDA = p_cod_moneda
      and B.FECHA <= pag_cal.FU_OBT_FEC_ACTUAL(9)
 order by FECHA desc;
begin
  -- Busco la oficina de la caja
  Begin
     select cod_oficina
       into p_cod_oficina
       from cj_cajas
      where nro_caja = p_nro_caja
        and (cod_usu_responsable = UPPER(USER) or p_val_usu_responsable = 'N') -- anulo para que
        and estado ='A'; --solo activas
      p_estado := 0; -- encontro registro
  exception
     when no_data_found then
      p_estado := -1; -- con error porque no existe
  end;
  if p_estado = 0 then
     if caja%isOpen then
       close caja;
     end if;
     open caja;
     fetch caja into p_fec_caja, p_estado, p_sal_actual, p_sal_cheques;
     if caja%notfound then
        p_estado := 0; -- sin ningun registro
        p_sal_actual := null;
        P_fec_caja := null;
        p_sal_cheques := null;
     end if;
     close caja;
  end if;
exception
   when others then
      raise_application_error(-20002, 'ERROR. en prj_obt_datos_caja '||sqlerrm);
end PRJ_OBT_DATOS_CAJA;
/

