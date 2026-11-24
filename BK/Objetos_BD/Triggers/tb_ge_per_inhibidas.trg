CREATE OR REPLACE TRIGGER IT.TB_GE_PER_INHIBIDAS
 BEFORE UPDATE
  ON GE_PER_INHIBIDAS
 FOR EACH ROW

BEGIN
  if :old.estado = 'D' then
      if :new.situacion <> 'R' then
         raise_application_error(-20001,'No se puede actualizar registros Rehabilitados');
      end if ;
  else
     if :new.estado = 'D' and :old.estado = 'I' then
         :new.fec_rehabilitacion := sysdate ;
         :new.situacion := 'R' ;
     end if ;
   end if ;
EXCEPTION
  WHEN OTHERS THEN
   If sqlcode <= -20000 then 
       raise;
   else
       raise_application_error(-20000, 'TB_GE_PER_INHIBIDAS -'||sqlerrm);
   end if;  
END TB_GE_PER_INHIBIDAS;
/

