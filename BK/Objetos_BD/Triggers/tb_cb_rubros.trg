CREATE OR REPLACE TRIGGER IT.TB_CB_RUBROS
 BEFORE DELETE OR INSERT OR UPDATE
 ON "IT"."CB_RUBROS"
 FOR EACH ROW
DECLARE
  FUNCTION LF_OBT_RUB_PADRE(p_cod_rubro in varchar2)
  RETURN varchar2 IS
  BEGIN
     if substr(p_cod_rubro,3,1) <> '0' then
        return substr(p_cod_rubro,1,2)||'0'||substr(p_cod_rubro,4,12);
        --return substr(p_cod_rubro,1,2)||'0'||substr(p_cod_rubro,4,10)||'00';
    
     elsif substr(p_cod_rubro,3,1) = '0' then
        return substr(p_cod_rubro,1,2)||'0'||substr(p_cod_rubro,4,7)||'00000';
     else
        return :new.cod_rub_padre;
     end if;
  END;
BEGIN
   if inserting then
      if :new.imputable = 'S' then --- Solo validar cuando es imputable
         if :new.cod_rubro = :new.cod_rub_padre then
            raise_application_error(-20000,'Rubro padre debe diferir del rubro principal');
         end if;
         if lf_obt_rub_padre(:new.cod_rubro) <> :new.cod_rub_padre Then
            raise_application_error(-20000,'Rubro padre no corresponde');
         end if;
      end if;
   elsif updating then
      if :new.cod_rub_padre <> :old.cod_rub_padre
      and :new.imputable = 'S' then --- Solo validar cuando es imputable
         if :new.cod_rubro = :new.cod_rub_padre then
            raise_application_error(-20000,'Rubro padre debe diferir del rubro principal');
         end if;
         if lf_obt_rub_padre(:new.cod_rubro) <> :new.cod_rub_padre Then
            raise_application_error(-20000,'Rubro padre no corresponde');
         end if;
      end if;
   end if;
END;
/

