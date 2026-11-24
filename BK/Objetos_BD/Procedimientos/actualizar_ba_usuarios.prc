create or replace procedure it.actualizar_ba_usuarios is
cursor riesgo is 
     --  select a.cod_usuario,a.gru_agenda from bbvba_usuarios a;
     select null cod_usuario,null gru_agenda from ba_usuarios a;
begin
   for x in riesgo loop
        update it.ba_usuarios b
                set b.gru_agenda=x.gru_agenda
                where b.cod_usuario=x.cod_usuario; 
        
    end loop;
 commit;   
end actualizar_ba_usuarios;
/

