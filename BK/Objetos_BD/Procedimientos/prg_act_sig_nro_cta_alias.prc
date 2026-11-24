CREATE OR REPLACE PROCEDURE it.prg_act_sig_nro_cta_alias(P_PARAMETRO     IN GE_PAR_DINAMICOS.PARAMETRO%TYPE,
                                                         P_COD_MODULO    IN GE_CUENTAS.COD_MODULO%TYPE,
                                                         P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE,
                                                         P_COD_OFICINA   IN GE_CUENTAS.COD_OFICINA%TYPE,
                                                         P_COD_MONEDA    IN GE_CUENTAS.COD_MONEDA%TYPE,
                                                         P_EXISTE        OUT VARCHAR2)IS
                                                         PRAGMA AUTONOMOUS_TRANSACTION;
v_rowid      varchar2(60);
v_nro_cuenta ge_par_dinamicos.val_parametro%type;
v_cod_moneda varchar2(1);
v_existe     VARCHAR2(1) := 'N';
v_max_sec    integer;
v_sgte       integer;

    FUNCTION lp_val_cta_alias (p_nro_cuenta GE_CUENTAS.NRO_CUENTA%TYPE)
                           RETURN VARCHAR2 IS
    v_existe  VARCHAR2(1) := 'N';
    BEGIN
        SELECT 'S'
          INTO v_existe
          FROM it.ah_cta_alias_vi
         WHERE nro_cta_alias = p_nro_cuenta;
          RETURN v_existe;
      EXCEPTION
        WHEN no_data_found THEN
          v_existe := 'N';
          RETURN v_existe;
        WHEN too_many_rows THEN
          v_existe := 'S';
          RETURN v_existe;
    END;
BEGIN
  if P_COD_MODULO = 3 and P_COD_MODALIDAD in (31,334) then
    SELECT last_number into v_max_sec  FROM all_sequences WHERE sequence_name = 'S_SIG_NRO_CTA_MAD_31';
    v_nro_cuenta := v_max_sec + 1;
  else
     -- leo el parametro que corresponde al siguiente Nro de cuenta
   select val_parametro, rowid
   into v_nro_cuenta, v_rowid
   from ge_par_dinamicos
   where nvl(cod_modulo,nvl(p_cod_modulo,-1)) = nvl(p_cod_modulo,-1)
   and nvl(cod_modalidad,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
   and nvl(cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
   and nvl(cod_moneda,nvl(p_cod_moneda,'x')) = nvl(p_cod_moneda,'x')
   and parametro = p_parametro
   for update nowait;
   -- Actualizo el parametro con el sgte nro de cuenta, considera si tiene 0 inicial
   update ge_par_dinamicos
   set val_parametro = VAL_PARAMETRO + 1
   where rowid = v_rowid;
   if sql%notfound then
      raise_application_error(-20000,'Sgte. Nro. de Cuenta no pudo ser modificado');
   end if;
  end if;
   --se agrega "0" + código de oficina + v_nro_cuenta para ambas modalidades
   If p_cod_modulo = 6 then
      if p_cod_oficina between 1 and 9 then
         v_nro_cuenta := '0'|| p_cod_oficina || to_char(sysdate,'yy') || v_nro_cuenta;
      else
         v_nro_cuenta := p_cod_oficina || to_char(sysdate,'yy') || v_nro_cuenta;
      end if;
   elsif p_cod_modulo = 3 then
     If p_cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
       v_cod_moneda := '9';
     else
       v_cod_moneda := '1';
     End if;

     if p_cod_oficina between 1 and 9 then
         v_nro_cuenta := '1'|| p_cod_oficina || v_cod_moneda || v_nro_cuenta;
     else
         v_nro_cuenta := p_cod_oficina || v_cod_moneda || v_nro_cuenta;
     end if;

      --Valido si la cuenta generada coincide con algun Alias Visión
      v_existe:= lp_val_cta_alias(v_nro_cuenta);
      IF v_existe = 'S' THEN
        if P_COD_MODULO = 3 and P_COD_MODALIDAD in (31,334) then
           v_sgte := TO_CHAR(s_sig_nro_cta_mad_31.NEXTVAL);
		else
		   COMMIT;
        end if;
      END IF;
   else
     if p_cod_oficina between 1 and 9 then
         v_nro_cuenta := '0'|| p_cod_oficina || v_nro_cuenta;

      else
         v_nro_cuenta := p_cod_oficina || v_nro_cuenta;
      end if;

      --Valido para el modulo 4 si la cuenta generada coincide con algun Alias Visión
      IF p_cod_modulo = 4 THEN
         v_existe:= lp_val_cta_alias(v_nro_cuenta);
        IF v_existe = 'S' THEN
          COMMIT;
          if P_COD_MODULO = 3 and P_COD_MODALIDAD in (31,334) then
            v_sgte := TO_CHAR(s_sig_nro_cta_mad_31.NEXTVAL);
          end if;
        END IF;
      END IF;
   End if;
   -- retorno el sgte nro de cuenta
   P_EXISTE:= v_existe;
EXCEPTION
   WHEN no_data_found THEN
      raise_application_error(-20001,'Parametro '||p_parametro||' no esta definido p/ Mod. '||
      to_char(p_cod_modulo)||' Mad.'||to_char(p_cod_modalidad)||' Mon.'||
      p_cod_moneda||' Ofi.'||to_char(p_cod_oficina) );
   WHEN too_many_rows then
      raise_application_error(-20002,'Parametro '||p_parametro||' esta duplicado en el Sistema. p/ Mod. '||
      to_char(p_cod_modulo)||' Mad.'||to_char(p_cod_modalidad)||' Mon.'||
      p_cod_moneda||' Ofi.'||to_char(p_cod_oficina) );
  WHEN OTHERS THEN
    if sqlcode = -54 then  -- registro bloqueado por otro usuario
         raise_application_error(-20003,'Registro utilizado por otro Usuario. Vuelva a intentarlo.');
    else
         P_EXISTE:= v_existe;
    end if;
END;
/
