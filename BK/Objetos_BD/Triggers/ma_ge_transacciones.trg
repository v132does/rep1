CREATE OR REPLACE TRIGGER IT.MA_GE_TRANSACCIONES
 AFTER DELETE OR UPDATE OR INSERT
 ON GE_TRANSACCIONES
 FOR EACH ROW
BEGIN
   IF inserting then
      if ((:new.cod_modalidad)in(31,32,33,41))and ((:new.tipo)in('C','D')) then
          insert 
          into ic_dtm_transacciones
               (cod_dtm_transaccion,
                cod_transaccion,
                cod_modulo,
                cod_modalidad,
                descripcion,
                tipo)
      values(s_cod_dtm_transaccion.nextval,
                :new.cod_transaccion,
                :new.cod_modulo,
                :new.cod_modalidad,
                :new.descripcion,
                :new.tipo);
      end if;
   elsif updating then
      if ((:old.cod_modalidad)in(31,32,33,41))and ((:old.tipo)in('C','D')) then
          if(:new.descripcion)<>(:old.descripcion) or (:new.tipo)<>(:old.tipo) then
                update ic_dtm_transacciones a
                       set a.descripcion=:new.descripcion,
                           a.tipo=:new.tipo
                       where a.cod_modulo=:old.cod_modulo
                             and a.cod_modalidad=:old.cod_modalidad
                             and a.cod_transaccion=:old.cod_transaccion;                                                              
          end if;
      end if;
   elsif deleting then
         if ((:old.cod_modalidad)in(31,32,33,41))and ((:old.tipo)in('C','D')) then
            delete ic_dtm_transacciones a
            where a.cod_transaccion=:old.cod_transaccion
            and a.cod_modulo=:old.cod_modulo
            and a.cod_modalidad=:old.cod_modalidad;
         end if;
   end if;
END;
/

