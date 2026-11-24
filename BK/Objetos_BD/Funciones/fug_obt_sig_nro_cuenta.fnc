CREATE OR REPLACE FUNCTION IT.FUG_OBT_SIG_NRO_CUENTA
 (P_COD_MODULO    IN GE_CUENTAS.COD_MODULO%TYPE,
  P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE,
  P_COD_OFICINA   IN GE_CUENTAS.COD_OFICINA%TYPE,
  P_COD_MONEDA    IN GE_CUENTAS.COD_MONEDA%TYPE,
  P_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN VARCHAR2
 IS
v_rowid      varchar2(60);
v_nro_cuenta ge_par_dinamicos.val_parametro%type;
v_parametro  varchar2(30) := 'SIG_NROCTA'; -- Parametro para el siguiente Nro de cuenta
v_cod_moneda varchar2(1);
v_existe     VARCHAR2(1) := 'N';
v_mad_cta    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MAD_VAL_CTA_ALIAS');

BEGIN
  --Se valida que vaya por uno u otro para evitar interbloqueo
  IF (instr(v_mad_cta, '#'||p_cod_modalidad||'#' ) > 0) THEN
     prg_act_sig_nro_cta_alias(V_PARAMETRO,P_COD_MODULO,P_COD_MODALIDAD,P_COD_OFICINA,P_COD_MONEDA,V_EXISTE);
        IF V_EXISTE = 'S' THEN
          v_nro_cuenta := null;
          raise_application_error(-20000,'El numero de cuenta generado ya existe como Alias.');
        END IF;
  END IF;
  if P_COD_MODULO = 3 and P_COD_MODALIDAD in (31,334,37) then
    v_nro_cuenta := TO_CHAR(s_sig_nro_cta_mad_31.NEXTVAL);
  else
   -- leo el parametro que corresponde al siguiente Nro de cuenta
   select val_parametro, rowid
   into v_nro_cuenta, v_rowid
   from ge_par_dinamicos
   where nvl(cod_modulo,nvl(p_cod_modulo,-1)) = nvl(p_cod_modulo,-1)
   and nvl(cod_modalidad,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
   and nvl(cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
   and nvl(cod_moneda,nvl(p_cod_moneda,'x')) = nvl(p_cod_moneda,'x')
   and parametro = v_parametro
   for update nowait;
   -- Actualizo el parametro con el sgte nro de cuenta, considera si tiene 0 inicial
   update ge_par_dinamicos
   set val_parametro = VAL_PARAMETRO + 1
   where rowid = v_rowid;
   if sql%notfound then
      raise_application_error(-20012,'Sgte. Nro. de Cuenta no pudo ser modificado');
   end if;
   commit; --Libera el bloqueo rápidamente PCON-321
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
   else
     if p_cod_oficina between 1 and 9 then
         v_nro_cuenta := '0'|| p_cod_oficina || v_nro_cuenta;

     else
         v_nro_cuenta := p_cod_oficina || v_nro_cuenta;
     end if;
   End if;
   -- retorno el sgte nro de cuenta
   Return v_nro_cuenta;
EXCEPTION
   WHEN no_data_found THEN
      raise_application_error(-20000,'Parametro SIG_NROCTA no esta definido p/ Mod. '||
      to_char(p_cod_modulo)||' Mad.'||to_char(p_cod_modalidad)||' Mon.'||
      p_cod_moneda||' Ofi.'||to_char(p_cod_oficina) );
   WHEN too_many_rows then
      raise_application_error(-20000,'Parametro SIG_NROCTA esta duplicado en el Sistema. p/ Mod. '||
      to_char(p_cod_modulo)||' Mad.'||to_char(p_cod_modalidad)||' Mon.'||
      p_cod_moneda||' Ofi.'||to_char(p_cod_oficina) );
   WHEN OTHERS THEN
      if sqlcode = -54 then  -- registro bloqueado por otro usuario
         raise_application_error(-20000,'Registro utilizado por otro Usuario. Vuelva a intentarlo.');
      else
         raise_application_error(-20000,'Sgte.Nro.de Cuenta-'||SQLERRM);
      end if;
END;
/
