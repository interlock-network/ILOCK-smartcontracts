/****************************************************************
 * ILOCKsupreme Solana Contract
 ****************************************************************/

#![allow(non_snake_case)]
use solana_program::{
        account_info::{
            next_account_info,
            AccountInfo
        },
        entrypoint::ProgramResult,
        program_error::ProgramError,
        program_pack::Pack,
        pubkey::Pubkey,
        clock::Clock,
        sysvar::Sysvar,
    };

use crate::{
        error::error::ContractError::*,
        processor::run::Processor,
        utils::utils::*,
        state::{
            GLOBAL::*,
            ENTITY::*,
        },
    };

// for this instruction, the expected accounts are:

impl Processor {

    pub fn process_settle_entity(
        _program_id: &Pubkey,
        accounts: &[AccountInfo],
        determination: u8,
    ) -> ProgramResult {

        // it is customary to iterate through accounts like so
        let account_info_iter = &mut accounts.iter();
        let owner = next_account_info(account_info_iter)?;
        let pdaGLOBAL = next_account_info(account_info_iter)?;
        let pdaENTITY = next_account_info(account_info_iter)?;
        let clock = next_account_info(account_info_iter)?;

        // get GLOBAL data
        let GLOBALinfo = GLOBAL::unpack_unchecked(&pdaGLOBAL.try_borrow_data()?)?;

        // get ENTITY  data
        let mut ENTITYinfo = ENTITY::unpack_unchecked(&pdaENTITY.try_borrow_data()?)?;
        let mut ENTITYflags = unpack_16_flags(ENTITYinfo.flags);

        // convert serialized determination from u8 into boolean
        let determination_bool: bool;
        if determination == 0 { determination_bool = false } else { determination_bool = true }

        // get timestamp to reset ENTITY timestamp
        let timestamp = Clock::from_account_info(&clock)?.unix_timestamp;

        // check to make sure tx sender is signer
        if !owner.is_signer {
            return Err(ProgramError::MissingRequiredSignature);
        }

        // check that owner is *actually* GLOBAL owner
        // only Interlock Network owner can settle entity
        if GLOBALinfo.owner != *owner.key {
            return Err(OwnerImposterError.into());
        }

        // make sure thresholds have been passed and entity is settling
        if !ENTITYflags[7] {
            return Err(EntityNotSettlingError.into());
        }

        // entity is of determination provided
        ENTITYflags.set(9, determination_bool);

        // entity is settled
        ENTITYflags.set(6, true);

        // update ENTITY
        ENTITYinfo.flags = pack_16_flags(ENTITYflags);
        ENTITYinfo.timestamp = timestamp;
        ENTITY::pack(ENTITYinfo, &mut pdaENTITY.try_borrow_mut_data()?)?;

        Ok(())
    }
}

