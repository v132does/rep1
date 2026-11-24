create or replace procedure it.PRA_ELI_TAR_DEBITO is
cursor cuenta is
       select a.nro_cuenta from AH_DEL_TAR_DEBITOS_TMP a;

begin
  Begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1 ; end ;
   for x in cuenta loop
        delete ah_tar_debitos b
                where b.nro_cuenta = x.nro_cuenta;

    end loop;
 commit;
end PRA_ELI_TAR_DEBITO;
/

