CREATE OR REPLACE PROCEDURE IT.PRC_REV_SOB_SUSPENSO
IS
--El objetivo es recorrer la tabla de sobregiros en suspenso (cc_sob_suspenso) y ver si la cuenta ya salió de gestión.
--La manera de ver si ya salio de gestion es primero ver en cc_cta_corriente si el saldo es menor a cero (esta sobregirada)
--si esta sobregirado buscar en cc_sobregiros la maxima fecha menor o igual a hoy y ver si esta o no en gestion,
--y si la cuenta no esta sobregirada en cc_cta_corriente entonces se asume que ya salio de gestion.

cursor c_sob_suspenso is
 select nro_cuenta, cod_modulo,cod_modalidad,cod_Transaccion,monto
   from cc_sob_suspenso
  where fec_regularizacion is null for update;

cursor c_rev_cargos is
  select ge.cod_modulo,ge.cod_modalidad,ge.nro_cuenta,ge.cod_transaccion,ge.fec_valor
    from ge_movimientos ge
   where ge.MONTO < 0
     and ge.COD_TRANSACCION in (select distinct css.cod_transaccion from cc_sob_suspenso css)
     and ge.reversado = 'N';

-- Variables
 v_saldo_cta       cc_Cta_corrientes.sal_total%type;
 v_cdofici         cc_Cta_corrientes.Cod_Oficina%type;
 v_cdmoned         cc_Cta_corrientes.Cod_moneda%type;
 v_sit_deuda       cc_sobregiros_res.sit_deuda%type;
 v_reverso         ge_movimientos.reversado%type;
 r_gmovi           ge_movimientos%rowtype;
 v_fcdehoy         date := pag_cal.FU_OBT_FEC_ACTUAL(4);
 v_can_user        number;
 v_cod_tra_reverso ge_movimientos.cod_transaccion%type;

  -- Variables para manejo de usuarios --
  v_usuario         ba_usuarios.cod_usuario%type;
  TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
  v_usu_secuencia   typ_usu_secuencia;  
  
  TYPE t_usu_hor IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
  v_usu_hora t_usu_hor;
  
BEGIN
   Begin pre_ini_aplicacion;pae_cnf.G_COD_MODULO:=1;end;
   --
   BEGIN
     SELECT COUNT(*)
       INTO v_can_user
       FROM ba_cod_referencias
       WHERE dominio     = 'USU_MOV_CIERRE'
         AND abreviatura = 'MOVCIERRE';
     EXCEPTION 
       WHEN OTHERS THEN 
         NULL;
   END;
   --Actualizo estado de cargos por sobregiros.
   For reg in c_rev_cargos loop
      update cc_sob_suspenso a
        set a.fec_regularizacion = v_fcdehoy
       where a.nro_cuenta = reg.nro_cuenta
         and a.cod_modulo = reg.cod_modulo
         and a.cod_modalidad = reg.cod_modalidad
         and a.cod_transaccion = reg.cod_transaccion
         and a.fecha = reg.fec_valor;
   End loop;
   --Genero movimientos contables de cargos por cobertura de sobregiros.
   For reg in c_sob_suspenso loop
     v_reverso := 'N';
     --- primero ver si sigue en sobregiro la cuenta
     Begin
      select cod_oficina, cod_moneda, NVL(sal_total,0) - nvl(sal_retenido,0)
        into v_cdofici, v_cdmoned, v_saldo_Cta
        From cc_cta_corrientes
       Where nro_cuenta = reg.nro_cuenta;
     Exception
       when others then
        raise_application_error(-20000,'ERROR.Recup. datos de la cuenta ' || reg.nro_cuenta);
     End;
     if  v_saldo_Cta  >= 0 then  -- ya no esta sobregirada, entonces sacar de suspenso
        v_reverso := 'S';
      else  --sigue en sobregiro, ver si ya salio de gestion
        IF reg.cod_transaccion <> 984 THEN -- SPCOGACO-1
          --Buscar el estado de la maxima fecha
          Begin
            Select sit_deuda into v_sit_deuda
              from cc_sobregiros_res
             where nro_cuenta = reg.nro_cuenta;
            if v_sit_deuda in('S','V') then  -- ya salio de gestion
               v_reverso := 'S';
            else
               v_reverso := 'N';  -- sigue en gestion
            end if;
          Exception
            when others then
               v_reverso := 'N';
          end;
        ELSE
           v_reverso := 'N';
        END IF;
      end if;
      -- Si ya no esta en gestion realizar el reverso
      If v_reverso = 'S' then
        --Obtengo la transacción.
         if reg.cod_transaccion in (980, 3980) then  --Interes x sobregiro
            v_cod_tra_reverso := 1980;
         elsif reg.cod_transaccion = 981 then  -- Exceso de días
            v_cod_tra_reverso := 1988;
         elsif reg.cod_transaccion = 982 then  -- Exceso de días - Nomina
            v_cod_tra_reverso := 1981;
         elsif reg.cod_transaccion = 988 then  -- Mayor Sobregiro
            v_cod_tra_reverso := 1988;
         elsif reg.cod_transaccion = 983 then  -- Seguro de vida Sobregiro
            v_cod_tra_reverso := 1983;
         elsif reg.cod_transaccion = 994 then  -- Liq. Gastos Sobregiro
            v_cod_tra_reverso := 1981;
				 elsif reg.cod_transaccion = 787 then  -- Liq. Gastos Sobregiro
            v_cod_tra_reverso := 1981;
         elsif reg.cod_transaccion = 984 then  -- Gastos Cobranzas Costo Real. SPCOGACO-1
            v_cod_tra_reverso := 1984;
         End if;
         
         -- Generar Movimiento de reverso del suspenso
         -- Calculo para multiusuario --
         v_usuario  := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
         
         -- Inicializar secuencia si es la primera vez para este usuario --
         IF NOT v_usu_secuencia.EXISTS(v_usuario) THEN
             v_usu_secuencia(v_usuario) := 0;
             v_usu_hora(v_usuario) := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E'); 
         END IF;
         -- Si llega al limite de secuencias, recalcular hora y resetear
         IF v_usu_secuencia(v_usuario) >= 995 THEN
            v_usu_secuencia(v_usuario) := 1;
            v_usu_hora(v_usuario)      :=  PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
         ELSE
          -- Se incrementa la secuencia del usuario
            v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
         END IF;

         r_gmovi.cod_modulo      := reg.cod_modulo;
         r_gmovi.cod_modalidad   := reg.cod_modalidad;
         r_gmovi.cod_oficina     := v_cdofici;
         r_gmovi.nro_cuenta      := reg.nro_cuenta;
         r_gmovi.cod_moneda      := v_cdmoned;         
         r_gmovi.cod_usuario     := v_usuario;
         r_gmovi.hora            := v_usu_hora(v_usuario);         
         r_gmovi.fecha           := v_fcdehoy;
         r_gmovi.fec_valor       := v_fcdehoy;
         r_gmovi.cod_mod_padre   := reg.cod_modulo;
         r_gmovi.cod_mad_padre   := reg.cod_modalidad;
         r_gmovi.nro_documento   := null;
         r_gmovi.nro_documento2  := null;
         r_gmovi.nro_documento3  := null;
         r_gmovi.cod_tasa        := null;
         r_gmovi.val_tasa        := null;
         r_gmovi.cotizacion      := null;
         r_gmovi.cod_ofi_origen  := v_cdofici;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.nro_secuencia   := v_usu_secuencia(v_usuario); -- Secuencia del usuario --
         r_gmovi.cod_tra_padre   := v_cod_tra_reverso;
         r_gmovi.cod_transaccion := v_cod_tra_reverso;
         r_gmovi.monto           := reg.monto;
         r_gmovi.concepto        := 'Reverso de cargo sobregiro en suspenso';
         pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
        -- Restar de cta.cte.
        Update cc_sobregiros_res
           set mto_sob_suspenso = nvl(mto_sob_suspenso,0) - reg.monto
         where nro_cuenta = reg.nro_cuenta;
        -- Marcar como regularizado en cc_sob_suspenso
        Update cc_sob_suspenso
           set fec_regularizacion = v_fcdehoy
         where current of c_sob_suspenso;
     END IF;
   END LOOP;
EXCEPTION
WHEN OTHERS THEN
   raise_application_error(-20000, 'ERROR. en Sobregiro '||SQLERRM);
END;

