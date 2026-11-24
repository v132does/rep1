CREATE OR REPLACE PROCEDURE IT.PRG_INS_CAN_ENTRADAS is
  cursor c_entradas is
    select b.cod_entrada, b.estado, b.cod_tip_entrada
      from bw_can_entradas_tmp b;
  begin
     for x in c_entradas loop
      begin
           insert into bw_can_entradas(cod_entrada, estado, cod_tip_entrada)
            values(x.cod_entrada, x.estado, x.cod_tip_entrada);

      exception
           when dup_val_on_index then
             raise_application_error(-20000, 'ERROR: '||user||' existen datos duplicados, favor verificar. '||sqlerrm);
           when others then
             raise_application_error(-20000, 'ERROR: '||user||' no se puede insertar los datos. '||sqlerrm);
           
       end;      
    end loop;
  exception
     when others then
        raise_application_error(-20001, 'Error al ejecutar procedimiento: '||sqlerrm);
  end;
/

