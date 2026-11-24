create or replace procedure it.prl_ini_sal_diarios
is
/*inicializa lc_sal_diarios para que el proceso de cierre
pueda genera los datos x oficina de cambio y moneda*/
cursor oficinas is
 select distinct (a.cod_ofi_cambio)
   from ba_oficinas a, ba_oficinas b
  where a.cod_ofi_cambio = b.cod_oficina
    and a.cod_ofi_cambio is not null
    and b.estado ='A';
cursor monedas is
  select distinct(cod_moneda)
    from ge_movimientos
   where cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
     and reversado = 'N'
     and estado = 'N'
     and cod_mod_padre =7;

v_existe number ;
begin
   for reg in oficinas loop
      for reg1 in monedas loop
         select nvl(count(*),0)
         into v_existe
         from lc_sal_diarios
         where cod_oficina = reg.cod_ofi_cambio
         and cod_moneda = reg1.cod_moneda;
         if v_existe = 0 then -- no existe insertar
            --insertar la posición
            insert into lc_sal_diarios
                (cod_oficina, cod_moneda, fecha,
                mto_pos_com_efe_ant, mto_pos_com_nef_ant,
                mto_pos_vta_efe_ant, mto_pos_vta_nef_ant)
            values
                (reg.cod_ofi_cambio, reg1.cod_moneda, pag_cal.FU_OBT_FEC_ACTUAL(7),
                 0, 0,
                 0, 0);
         end if;
      end loop;
   end loop;
end;
/

