CREATE OR REPLACE TRIGGER IT.TB_GE_SAL_INV_VTA_CARTERA_TMP
 BEFORE UPDATE
 ON GE_SAL_INV_VTA_CARTERA_TMP
 FOR EACH ROW
BEGIN 
   if updating then
     --Si se modifico el check de estado, se carga el campo usu_exclucion
     If nvl(:old.estado, 'x') = 'N' and nvl(:new.estado, 'x') = 'E' then
       :new.usu_exclucion := user;
     end if;
   end if;  
END;
/

