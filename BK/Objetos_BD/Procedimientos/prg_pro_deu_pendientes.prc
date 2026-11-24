CREATE OR REPLACE PROCEDURE IT."PRG_PRO_DEU_PENDIENTES" is

cursor c_deuda_pendientes is
       select * from mi_deu_pendientes mdp order by nro_cuenta;
c_datos_deuda c_deuda_pendientes%rowtype;
begin
  open c_deuda_pendientes;
    loop
      fetch c_deuda_pendientes into c_datos_deuda;
        if c_deuda_pendientes%found then
          begin
             PRG_BLO_DEU_PENDIENTES(c_datos_deuda.nro_cuenta,c_datos_deuda.mto_deuda,0);
          Exception
          when others then
             null;             
          end;
          commit;
        end if;
      exit when c_deuda_pendientes%notfound;
    end loop;
  close c_deuda_pendientes;
exception
when others then
   update simgia_ardeupend set est_proceso = null, respuesta = null where nro_cuenta = c_datos_deuda.nro_cuenta;
   commit;
     RAISE_APPLICATION_ERROR(-20000,'Error:'||c_datos_deuda.nro_cuenta||'  '||c_datos_deuda.mto_deuda||' '||sqlerrm);
end PRG_PRO_DEU_PENDIENTES;
/

