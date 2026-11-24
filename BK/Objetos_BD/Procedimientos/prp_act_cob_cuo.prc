CREATE OR REPLACE PROCEDURE IT.PRP_ACT_COB_CUO IS
cursor c_movim is
Select m.nro_cuenta, m.hora
  from ge_movimientos m
 where m.fecha = '30.03.2020'
   and m.cod_usuario = 'PY01061'
   and m.fec_valor = '20.03.2020'
   and m.nro_cuenta is not null
group by m.nro_cuenta, m.hora;
begin
  BEGIN   PRE_INI_APLICACION;   PAE_CNF.G_COD_MODULO := 1;  END;
  for m in c_movim loop
    begin
      update pr_cobros p
         set hora = m.hora
       where p.fecha = '30.03.2020'
         and p.usu_insercion = 'PY01061'
         and p.nro_cuenta = m.nro_cuenta;
    exception
      when others then
        raise_application_error(-20001,'cta: '||m.nro_cuenta||' hora: '||m.hora||' '||sqlerrm);
    end;
    commit;
  end loop;
end;
/

