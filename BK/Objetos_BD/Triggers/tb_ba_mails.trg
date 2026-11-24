CREATE OR REPLACE TRIGGER IT.TB_BA_MAILS
 BEFORE INSERT OR UPDATE
 ON BA_MAILS
 FOR EACH ROW
DECLARE
  v_mail         varchar2(319) := :new.dir_correo;
  v_nom_usuario  varchar2(64);
  v_nom_dominio  varchar2(254);
  v_caracter     varchar2(1);
  v_posicion     number(3);
  v_car_invalido number(3);
  v_con_caracter number(3) := 0;
  --
BEGIN
  If :new.tipo <> 'S' then
      ---
      v_posicion := instr(v_mail,'@');
      v_nom_usuario := substr(v_mail,1,instr(v_mail,'@')-1);
      v_nom_dominio := substr(v_mail,instr(v_mail,'@')+1);
      
      v_car_invalido := instr(translate(v_mail,' áéíóúàèìòùÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ,+´~|°ºª¬!"#$%&/()=?¡¿*¨{}^`·[]:;><ÇÃ%''',
                                               '******************************************************************'),'*');
                                               
      for i in 1..length(v_mail) loop
        v_caracter := substr(v_mail,i,1);
        if v_caracter = '@' then
          v_con_caracter := v_con_caracter + 1;
        end if;
      end loop;
      
      if v_posicion <= 1 or v_posicion = length(v_mail) or v_con_caracter > 1 then
        RAISE_APPLICATION_ERROR(-20000,'Direccion de Correo debe tener un único @ que no este al principio ni al final');
      elsif substr(v_nom_usuario,1,1) = '.' or substr(v_nom_usuario,length(v_nom_usuario),1) = '.' then
        RAISE_APPLICATION_ERROR(-20000,'Usuario No puede empezar ni terminar con un punto');
      elsif substr(v_nom_dominio,1,1) = '.' or substr(v_nom_dominio,length(v_nom_dominio),1) = '.' or instr(v_nom_dominio,'.') = 0 then
        RAISE_APPLICATION_ERROR(-20000,'Domimio debe terner al menos un punto que No este al principio ni al final');
      elsif v_car_invalido > 0 then
        RAISE_APPLICATION_ERROR(-20000,'Carater inválido: '|| substr(v_mail,v_car_invalido,1));
      elsif instr(v_mail,'..') > 0 then
        RAISE_APPLICATION_ERROR(-20000,'No puede ingresar punto consecutivamente');
      elsif length(v_nom_usuario) > 64 then
        RAISE_APPLICATION_ERROR(-20000,'El nombre de usuario no puede ser mayor a 64 caracteres');
      elsif length(v_nom_dominio) > 255 then
        RAISE_APPLICATION_ERROR(-20000,'El dominio no puede ser mayor a 255 caracteres');
      end if;
      if :new.tipo = 'H' and pae_cnf.G_PROGRAMA in ('ERCAPERS','ERREPERS') then
         raise_application_error(-20000,'No se permite ingresar/actualizar Mail tipo BBVAnet');
      end if;
      --
  End If;       
END;
/

