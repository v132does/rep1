CREATE OR REPLACE PACKAGE IT.pat_gol IS

  FUNCTION fu_obt_mon_consumo(p_cod_persona in ba_personas.cod_persona%type,
                              p_periodo     in number) RETURN number;

  FUNCTION fu_obt_dat_cliente(p_cod_persona in ba_personas.cod_persona%type)
    RETURN varchar2;

  PROCEDURE pr_arc_cuentas;

  PROCEDURE pr_arc_clientes;

  PROCEDURE pr_arc_transacciones;

  PROCEDURE pr_imp_cli_adheridos;

  PROCEDURE pr_pos_cli_adheridos;
  
  FUNCTION fu_obt_tar_debito(p_nro_cuenta in ge_cuentas.nro_cuenta%type) return number;

END pat_gol;
/

